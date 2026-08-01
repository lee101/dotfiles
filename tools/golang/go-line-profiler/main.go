// go-line-profiler: Analyze Go CPU profiles with multi-view output.
// Filters out stdlib and vendor code to focus on your project's hot paths.
//
// Views:
//
//	-view top         Slowest functions by cumulative time (default)
//	-view tree        Call tree with parent→child relationships
//	-view bottleneck  Where CPU actually spins (sorted by flat time)
//	-view callers     Caller/callee context for top functions
//	-view detail      Per-line CPU time for hot functions (-detail to filter)
//	-view all         All views combined
//	-view diff        Compare two profiles (-base required)
//
// Usage:
//
//	go run . -prof cpu.prof -root bulletgo
//	go run . -prof cpu.prof -root bulletgo -view tree
//	go run . -prof cpu.prof -root bulletgo -view detail
//	go run . -prof cpu.prof -root bulletgo -view detail -detail "QueryCircle"
//	go run . -prof cpu.prof -root bulletgo -view all
//	go run . -prof cpu.prof -base old.prof -root bulletgo -view diff
//	go run . -prof cpu.prof -root bulletgo -html hotspots.html
package main

import (
	"bufio"
	"flag"
	"fmt"
	"html"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

// entry represents a single pprof output row (line or function).
type entry struct {
	FlatPct float64
	FlatVal string
	CumPct  float64
	CumVal  string
	Name    string // function name or file:line
	File    string // extracted file path
	Line    int    // extracted line number (0 if function mode)
}

// treeNode represents a node in the call tree.
type treeNode struct {
	Name     string
	FlatVal  string
	FlatPct  float64
	CumVal   string
	CumPct   float64
	Children []*treeNode
	Depth    int
}

// fileHeat aggregates per-line heat data for HTML heatmap rendering.
type fileHeat struct {
	Path      string
	TotalCum  float64
	Lines     map[int]*lineHeat
	MaxLine   int
	SrcLoaded bool
	Src       []string
}

type lineHeat struct {
	FlatPct float64
	CumPct  float64
}

// detailFunc holds per-line profiling data for a single function (from pprof -list).
type detailFunc struct {
	Name     string
	File     string
	FlatVal  string
	CumVal   string
	TotalPct float64
	Lines    []detailLine
}

// detailLine holds per-line CPU time from pprof -list output.
type detailLine struct {
	LineNo int
	Flat   string  // "30ms" or "."
	Cum    string  // "130ms" or "."
	Source string
	FlatNs float64 // parsed nanoseconds for heat coloring
	CumNs  float64
}

func main() {
	profPath := flag.String("prof", "", "Path to .prof file (required)")
	basePath := flag.String("base", "", "Base profile for diff mode")
	rootPrefix := flag.String("root", "", "Project module prefix (default: auto-detect)")
	topN := flag.Int("top", 30, "Show top N entries per view")
	view := flag.String("view", "top", "View: top, tree, bottleneck, callers, detail, all, diff")
	detailFilter := flag.String("detail", "", "Function name regex for detail view (default: top 10 by flat)")
	htmlOut := flag.String("html", "", "Output HTML heatmap to file")
	minPct := flag.Float64("min", 0.1, "Minimum cum% threshold")
	flag.Parse()

	if *profPath == "" {
		fmt.Fprintln(os.Stderr, "Error: -prof is required")
		flag.Usage()
		os.Exit(1)
	}

	if *rootPrefix == "" {
		*rootPrefix = detectModulePath()
		if *rootPrefix == "" {
			fmt.Fprintln(os.Stderr, "Warning: no module path detected, showing all. Use -root to filter.")
		}
	}

	if *view == "diff" && *basePath == "" {
		fmt.Fprintln(os.Stderr, "Error: -base is required for diff view")
		os.Exit(1)
	}

	if *htmlOut != "" {
		if err := generateHTML(*profPath, *basePath, *rootPrefix, *htmlOut, *topN, *minPct, *detailFilter); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		return
	}

	switch *view {
	case "top":
		printTopView(*profPath, *rootPrefix, *topN, *minPct)
	case "tree":
		printTreeView(*profPath, *rootPrefix, *topN)
	case "bottleneck":
		printBottleneckView(*profPath, *rootPrefix, *topN, *minPct)
	case "callers":
		printCallersView(*profPath, *rootPrefix, *topN, *minPct)
	case "detail":
		printDetailView(*profPath, *rootPrefix, *topN, *minPct, *detailFilter)
	case "all":
		printAllViews(*profPath, *rootPrefix, *topN, *minPct, *detailFilter)
	case "diff":
		printDiffView(*profPath, *basePath, *rootPrefix, *topN, *minPct)
	default:
		fmt.Fprintf(os.Stderr, "Unknown view: %s\n", *view)
		os.Exit(1)
	}
}

// ═══════════════════════════════════════════════════════════════════
// View: top (cumulative-sorted function/line list)
// ═══════════════════════════════════════════════════════════════════

func printTopView(profPath, root string, topN int, minPct float64) {
	funcs := mustRunPprof(profPath, "-functions", "-cum")
	filtered := filterEntries(funcs, root, minPct)
	if len(filtered) > topN {
		filtered = filtered[:topN]
	}

	sectionHeader("SLOWEST FUNCTIONS (cumulative)")
	printEntryTable(filtered)
}

// ═══════════════════════════════════════════════════════════════════
// View: bottleneck (flat-sorted — where CPU actually spins)
// ═══════════════════════════════════════════════════════════════════

func printBottleneckView(profPath, root string, topN int, minPct float64) {
	funcs := mustRunPprof(profPath, "-functions", "-flat")
	filtered := filterEntries(funcs, root, 0)
	// Sort by flat% descending.
	sort.Slice(filtered, func(i, j int) bool {
		return filtered[i].FlatPct > filtered[j].FlatPct
	})
	// Filter out entries with no flat time.
	var withFlat []entry
	for _, e := range filtered {
		if e.FlatPct >= minPct {
			withFlat = append(withFlat, e)
		}
	}
	if len(withFlat) > topN {
		withFlat = withFlat[:topN]
	}

	sectionHeader("BOTTLENECK FUNCTIONS (flat CPU time — where the CPU actually spins)")
	if len(withFlat) == 0 {
		fmt.Println("  (no entries with significant flat time)")
		return
	}

	maxFlat := withFlat[0].FlatPct
	for i, e := range withFlat {
		color := heatColor(e.FlatPct, maxFlat)
		reset := "\033[0m"
		name := shortName(e.Name)
		fmt.Printf("  %s%2d. %-8s (%5.1f%% flat, %5.1f%% cum)  %s%s\n",
			color, i+1, e.FlatVal, e.FlatPct, e.CumPct, name, reset)
	}
	fmt.Println()
}

// ═══════════════════════════════════════════════════════════════════
// View: tree (call tree with indentation)
// ═══════════════════════════════════════════════════════════════════

func printTreeView(profPath, root string, topN int) {
	output := mustRunPprofRaw(profPath, "-tree", "-cum", "-nodecount=60")
	nodes := parseTreeOutput(output, root)

	sectionHeader("CALL TREE (cumulative)")
	if len(nodes) == 0 {
		fmt.Println("  (no matching tree nodes)")
		return
	}

	printed := 0
	for _, n := range nodes {
		if printed >= topN {
			break
		}
		printed += printTreeNode(n, topN-printed)
	}
	fmt.Println()
}

func printTreeNode(n *treeNode, remaining int) int {
	if remaining <= 0 {
		return 0
	}
	indent := strings.Repeat("  ", n.Depth)
	prefix := ""
	if n.Depth > 0 {
		prefix = "-> "
	}

	name := shortFuncName(n.Name)
	cumStr := n.CumVal
	if cumStr == "" {
		cumStr = fmt.Sprintf("%.1f%%", n.CumPct)
	}

	color := ""
	reset := ""
	if n.CumPct > 20 {
		color = "\033[91m" // red
		reset = "\033[0m"
	} else if n.CumPct > 5 {
		color = "\033[93m" // yellow
		reset = "\033[0m"
	}

	hotMarker := ""
	if n.FlatPct > 2 {
		hotMarker = fmt.Sprintf(" [%.1f%% flat]", n.FlatPct)
	}

	fmt.Printf("  %s%s%s%s (%s)%s%s\n", color, indent, prefix, name, cumStr, hotMarker, reset)
	count := 1

	for _, child := range n.Children {
		count += printTreeNode(child, remaining-count)
		if count >= remaining {
			break
		}
	}
	return count
}

// ═══════════════════════════════════════════════════════════════════
// View: callers (caller/callee context for hot functions)
// ═══════════════════════════════════════════════════════════════════

func printCallersView(profPath, root string, topN int, minPct float64) {
	// Get top functions first.
	funcs := mustRunPprof(profPath, "-functions", "-cum")
	filtered := filterEntries(funcs, root, minPct)
	if len(filtered) > 10 {
		filtered = filtered[:10]
	}

	sectionHeader("CALLER/CALLEE CONTEXT (top functions)")

	// Parse tree output once for caller/callee data.
	treeOut := mustRunPprofRaw(profPath, "-tree", "-cum", "-nodecount=100")
	callerMap := parseCallerCallee(treeOut, root)

	for _, e := range filtered {
		funcName := extractFuncName(e.Name)
		color := "\033[96m" // cyan
		reset := "\033[0m"
		fmt.Printf("\n  %s%s%s  %s cum (%5.1f%%),  %s flat (%5.1f%%)\n",
			color, shortFuncName(funcName), reset, e.CumVal, e.CumPct, e.FlatVal, e.FlatPct)

		if info, ok := callerMap[funcName]; ok {
			if len(info.callers) > 0 {
				fmt.Println("    Called by:")
				for _, c := range info.callers {
					fmt.Printf("      <- %s (%s)\n", shortFuncName(c.name), c.val)
				}
			}
			if len(info.callees) > 0 {
				fmt.Println("    Calls:")
				for _, c := range info.callees {
					marker := ""
					if c.pct > 10 {
						marker = " <-"
					}
					fmt.Printf("      -> %s (%s)%s\n", shortFuncName(c.name), c.val, marker)
				}
			}
		}
	}
	fmt.Println()
}

// ═══════════════════════════════════════════════════════════════════
// View: detail (per-line CPU time via pprof -list)
// ═══════════════════════════════════════════════════════════════════

func printDetailView(profPath, root string, topN int, minPct float64, detailFilter string) {
	funcs := getDetailFuncs(profPath, root, topN, minPct, detailFilter)
	if len(funcs) == 0 {
		sectionHeader("FUNCTION DETAIL (per-line CPU)")
		fmt.Println("  (no matching functions)")
		return
	}

	sectionHeader("FUNCTION DETAIL (per-line CPU)")
	for i, fn := range funcs {
		if i >= topN {
			break
		}
		printDetailFunc(fn)
	}
}

func getDetailFuncs(profPath, root string, topN int, minPct float64, detailFilter string) []detailFunc {
	if detailFilter != "" {
		// User specified a function regex — use it directly.
		return mustRunPprofList(profPath, detailFilter)
	}

	// Auto-drill: get top functions by flat time, then run -list for each.
	flat := mustRunPprof(profPath, "-functions", "-flat")
	filtered := filterEntries(flat, root, 0)
	sort.Slice(filtered, func(i, j int) bool {
		return filtered[i].FlatPct > filtered[j].FlatPct
	})

	limit := 10
	if limit > topN {
		limit = topN
	}

	var allFuncs []detailFunc
	seen := make(map[string]bool)
	for _, e := range filtered {
		if e.FlatPct < minPct {
			break
		}
		if len(allFuncs) >= limit {
			break
		}
		funcName := extractFuncName(e.Name)
		// Use the last component for the -list regex (avoid special chars in full path).
		shortN := shortFuncName(funcName)
		// Escape regex special chars in function name.
		escaped := regexp.QuoteMeta(shortN)
		if seen[escaped] {
			continue
		}
		seen[escaped] = true

		funcs := mustRunPprofList(profPath, escaped)
		for _, fn := range funcs {
			if !seen[fn.Name] {
				seen[fn.Name] = true
				allFuncs = append(allFuncs, fn)
			}
		}
	}
	return allFuncs
}

func printDetailFunc(fn detailFunc) {
	cyan := "\033[96m"
	reset := "\033[0m"
	dim := "\033[90m"
	name := shortFuncName(fn.Name)
	fmt.Printf("\n  %s%s%s  %s flat, %s cum  (%.1f%% of Total)\n",
		cyan, name, reset, fn.FlatVal, fn.CumVal, fn.TotalPct)
	fmt.Printf("  %s%s%s\n", dim, fn.File, reset)

	// Find max flat for heat scaling within this function.
	maxFlatNs := 0.0
	for _, dl := range fn.Lines {
		if dl.FlatNs > maxFlatNs {
			maxFlatNs = dl.FlatNs
		}
	}

	for _, dl := range fn.Lines {
		color := ""
		lineReset := ""
		if maxFlatNs > 0 && dl.FlatNs > 0 {
			ratio := dl.FlatNs / maxFlatNs
			if ratio > 0.5 {
				color = "\033[91m" // red — hottest
				lineReset = reset
			} else if ratio > 0.2 {
				color = "\033[93m" // yellow
				lineReset = reset
			} else {
				color = "\033[33m" // dim yellow
				lineReset = reset
			}
		} else if dl.CumNs > 0 {
			color = "\033[32m" // green — cum only
			lineReset = reset
		}

		flat := fmt.Sprintf("%10s", dl.Flat)
		cum := fmt.Sprintf("%10s", dl.Cum)
		fmt.Printf("    %s%s %s %5d:%s%s\n", color, flat, cum, dl.LineNo, dl.Source, lineReset)
	}
	fmt.Println()
}

// ═══════════════════════════════════════════════════════════════════
// View: diff (compare two profiles)
// ═══════════════════════════════════════════════════════════════════

func printDiffView(newProf, oldProf, root string, topN int, minPct float64) {
	newEntries := mustRunPprof(newProf, "-functions", "-cum")
	oldEntries := mustRunPprof(oldProf, "-functions", "-cum")

	newFiltered := filterEntries(newEntries, root, 0)
	oldFiltered := filterEntries(oldEntries, root, 0)

	// Build lookup by function name.
	oldMap := make(map[string]entry)
	for _, e := range oldFiltered {
		key := extractFuncName(e.Name)
		oldMap[key] = e
	}

	sectionHeader("PROFILE DIFF (new vs base)")
	fmt.Printf("  %-40s  %8s  %8s  %8s\n", "Function", "Old", "New", "Delta")
	fmt.Println("  " + strings.Repeat("-", 72))

	shown := 0
	for _, ne := range newFiltered {
		if shown >= topN {
			break
		}
		key := extractFuncName(ne.Name)
		oe, existed := oldMap[key]

		delta := ne.CumPct
		oldPct := 0.0
		if existed {
			oldPct = oe.CumPct
			delta = ne.CumPct - oe.CumPct
		}

		if math.Abs(delta) < minPct && ne.CumPct < minPct {
			continue
		}

		color := "\033[32m" // green (improvement)
		if delta > 0.5 {
			color = "\033[91m" // red (regression)
		} else if delta > 0 {
			color = "\033[93m" // yellow (slight regression)
		}
		reset := "\033[0m"

		sign := "+"
		if delta < 0 {
			sign = ""
		}

		name := shortFuncName(key)
		if len(name) > 38 {
			name = name[:35] + "..."
		}

		fmt.Printf("  %s%-40s  %7.1f%%  %7.1f%%  %s%.1f%%%s\n",
			color, name, oldPct, ne.CumPct, sign, delta, reset)
		shown++
	}

	// Show functions that disappeared (were in old but not new).
	for key, oe := range oldMap {
		found := false
		for _, ne := range newFiltered {
			if extractFuncName(ne.Name) == key {
				found = true
				break
			}
		}
		if !found && oe.CumPct >= minPct {
			name := shortFuncName(key)
			if len(name) > 38 {
				name = name[:35] + "..."
			}
			fmt.Printf("  \033[32m%-40s  %7.1f%%  %7s  -%.1f%%\033[0m\n",
				name, oe.CumPct, "gone", oe.CumPct)
		}
	}
	fmt.Println()
}

// ═══════════════════════════════════════════════════════════════════
// View: all (combined multi-section output)
// ═══════════════════════════════════════════════════════════════════

func printAllViews(profPath, root string, topN int, minPct float64, detailFilter string) {
	// Section 1: Top functions (cumulative).
	funcs := mustRunPprof(profPath, "-functions", "-cum")
	filtered := filterEntries(funcs, root, minPct)
	top := filtered
	if len(top) > topN {
		top = top[:topN]
	}
	sectionHeader("SLOWEST FUNCTIONS (cumulative)")
	printEntryTable(top)

	// Section 2: Bottleneck (flat).
	flat := mustRunPprof(profPath, "-functions", "-flat")
	flatFiltered := filterEntries(flat, root, 0)
	sort.Slice(flatFiltered, func(i, j int) bool {
		return flatFiltered[i].FlatPct > flatFiltered[j].FlatPct
	})
	var bottlenecks []entry
	for _, e := range flatFiltered {
		if e.FlatPct >= minPct {
			bottlenecks = append(bottlenecks, e)
		}
	}
	if len(bottlenecks) > 15 {
		bottlenecks = bottlenecks[:15]
	}
	sectionHeader("BOTTLENECK FUNCTIONS (flat CPU time)")
	if len(bottlenecks) > 0 {
		maxFlat := bottlenecks[0].FlatPct
		for i, e := range bottlenecks {
			color := heatColor(e.FlatPct, maxFlat)
			reset := "\033[0m"
			fmt.Printf("  %s%2d. %-8s (%5.1f%% flat, %5.1f%% cum)  %s%s\n",
				color, i+1, e.FlatVal, e.FlatPct, e.CumPct, shortName(e.Name), reset)
		}
	}
	fmt.Println()

	// Section 3: Call tree (abbreviated).
	treeOut := mustRunPprofRaw(profPath, "-tree", "-cum", "-nodecount=40")
	nodes := parseTreeOutput(treeOut, root)
	sectionHeader("CALL TREE (top path)")
	printed := 0
	for _, n := range nodes {
		if printed >= 20 {
			break
		}
		printed += printTreeNode(n, 20-printed)
	}
	fmt.Println()

	// Section 4: Function detail (top 5 by flat time).
	detailFuncs := getDetailFuncs(profPath, root, 5, minPct, detailFilter)
	if len(detailFuncs) > 0 {
		sectionHeader("FUNCTION DETAIL (per-line CPU — top 5)")
		for i, fn := range detailFuncs {
			if i >= 5 {
				break
			}
			printDetailFunc(fn)
		}
	}
}

// ═══════════════════════════════════════════════════════════════════
// pprof execution and parsing
// ═══════════════════════════════════════════════════════════════════

func mustRunPprof(profPath, granularity, sortFlag string) []entry {
	output := mustRunPprofRaw(profPath, granularity, "-text", sortFlag, "-nodecount=200")
	entries, err := parsePprofText(output)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Parse error: %v\n", err)
		os.Exit(1)
	}
	return entries
}

func mustRunPprofRaw(profPath string, args ...string) string {
	cmdArgs := append([]string{"tool", "pprof"}, args...)
	cmdArgs = append(cmdArgs, profPath)
	cmd := exec.Command("go", cmdArgs...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		fmt.Fprintf(os.Stderr, "pprof %s failed: %v\n%s\n", strings.Join(args, " "), err, string(out))
		os.Exit(1)
	}
	return string(out)
}

// mustRunPprofList runs `pprof -list="regex"` and parses the per-line output.
func mustRunPprofList(profPath, funcRegex string) []detailFunc {
	listArg := fmt.Sprintf("-list=%s", funcRegex)
	cmdArgs := []string{"tool", "pprof", listArg, profPath}
	cmd := exec.Command("go", cmdArgs...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		// -list with no matches returns exit code 0 normally,
		// but some versions may return error. Treat as empty.
		return nil
	}
	return parsePprofList(string(out))
}

// pprof -list output format:
//
//	ROUTINE ======================== pkg.func in /path/to/file.go
//	     30ms      130ms (flat, cum)  9.35% of Total
//	        .          .   6335:func (e *GameEngine) ...
//	        .       90ms   6339:	neighbors := ...
//	     10ms       10ms   6356:		dSq := ...
var (
	listHeaderRe = regexp.MustCompile(
		`^ROUTINE\s+=+\s+(\S+)\s+in\s+(.+)$`,
	)
	listTotalRe = regexp.MustCompile(
		`^\s*(\S+)\s+(\S+)\s+\(flat, cum\)\s+(\S+)%\s+of Total`,
	)
	listLineRe = regexp.MustCompile(
		`^\s*(\S+)\s+(\S+)\s+(\d+):(.*)$`,
	)
)

func parsePprofList(output string) []detailFunc {
	var funcs []detailFunc
	var current *detailFunc

	for _, line := range strings.Split(output, "\n") {
		// Check for ROUTINE header.
		if m := listHeaderRe.FindStringSubmatch(line); m != nil {
			if current != nil {
				funcs = append(funcs, *current)
			}
			current = &detailFunc{
				Name: m[1],
				File: strings.TrimSpace(m[2]),
			}
			continue
		}

		if current == nil {
			continue
		}

		// Check for totals line.
		if m := listTotalRe.FindStringSubmatch(line); m != nil {
			current.FlatVal = m[1]
			current.CumVal = m[2]
			current.TotalPct, _ = strconv.ParseFloat(m[3], 64)
			continue
		}

		// Check for source line.
		if m := listLineRe.FindStringSubmatch(line); m != nil {
			lineNo, _ := strconv.Atoi(m[3])
			dl := detailLine{
				LineNo: lineNo,
				Flat:   m[1],
				Cum:    m[2],
				Source:  m[4],
				FlatNs: parseDuration(m[1]),
				CumNs:  parseDuration(m[2]),
			}
			current.Lines = append(current.Lines, dl)
		}
	}

	if current != nil {
		funcs = append(funcs, *current)
	}
	return funcs
}

// parseDuration converts pprof duration strings like "30ms", "1.20s", "." to nanoseconds.
func parseDuration(s string) float64 {
	s = strings.TrimSpace(s)
	if s == "." || s == "" || s == "0" {
		return 0
	}
	// Try common suffixes.
	if strings.HasSuffix(s, "ns") {
		v, _ := strconv.ParseFloat(strings.TrimSuffix(s, "ns"), 64)
		return v
	}
	if strings.HasSuffix(s, "us") || strings.HasSuffix(s, "µs") {
		trimmed := strings.TrimSuffix(s, "us")
		trimmed = strings.TrimSuffix(trimmed, "µs")
		v, _ := strconv.ParseFloat(trimmed, 64)
		return v * 1e3
	}
	if strings.HasSuffix(s, "ms") {
		v, _ := strconv.ParseFloat(strings.TrimSuffix(s, "ms"), 64)
		return v * 1e6
	}
	if strings.HasSuffix(s, "s") {
		v, _ := strconv.ParseFloat(strings.TrimSuffix(s, "s"), 64)
		return v * 1e9
	}
	// Fallback: try as float.
	v, _ := strconv.ParseFloat(s, 64)
	return v
}

var pprofLineRe = regexp.MustCompile(
	`^\s*(\S+)\s+(\S+%)\s+\S+%\s+(\S+)\s+(\S+%)\s+(.+)$`,
)

func parsePprofText(output string) ([]entry, error) {
	var entries []entry
	scanner := bufio.NewScanner(strings.NewReader(output))
	inData := false
	for scanner.Scan() {
		line := scanner.Text()
		if !inData {
			if strings.Contains(line, "flat") && strings.Contains(line, "cum") &&
				!strings.Contains(line, "Showing") && !strings.Contains(line, "Dropped") {
				inData = true
			}
			continue
		}
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		m := pprofLineRe.FindStringSubmatch(line)
		if m == nil {
			continue
		}
		e := entry{
			FlatPct: parsePct(m[2]),
			FlatVal: m[1],
			CumPct:  parsePct(m[4]),
			CumVal:  m[3],
			Name:    strings.TrimSpace(m[5]),
		}
		e.File, e.Line = extractFileLine(e.Name)
		entries = append(entries, e)
	}
	return entries, scanner.Err()
}

// ═══════════════════════════════════════════════════════════════════
// Tree output parsing
// ═══════════════════════════════════════════════════════════════════

// parseTreeOutput parses pprof -tree output into a tree structure.
// Tree format has separator lines (---+---) between blocks, with
// callers above the main entry and callees below.
func parseTreeOutput(output, root string) []*treeNode {
	var roots []*treeNode
	seen := make(map[string]bool)

	// Parse blocks separated by dashes.
	blocks := strings.Split(output, strings.Repeat("-", 10))

	for _, block := range blocks {
		lines := strings.Split(block, "\n")
		var mainLine string
		var childLines []string

		// Find the main entry (line with | at start and flat/cum values).
		foundMain := false
		for _, line := range lines {
			trimmed := strings.TrimSpace(line)
			if trimmed == "" || strings.HasPrefix(trimmed, "File:") ||
				strings.HasPrefix(trimmed, "Type:") || strings.HasPrefix(trimmed, "Showing") ||
				strings.HasPrefix(trimmed, "Dropped") || strings.HasPrefix(trimmed, "Duration:") ||
				strings.HasPrefix(trimmed, "Build") || strings.HasPrefix(trimmed, "Time:") {
				continue
			}
			if !foundMain {
				// Main line has the flat/cum values without leading spaces before the pipe.
				if hasFlatCum(trimmed) && !strings.HasPrefix(trimmed, " ") {
					mainLine = trimmed
					foundMain = true
					continue
				}
			} else {
				// After main line, callee lines are indented with leading spaces.
				if hasFlatCum(trimmed) {
					childLines = append(childLines, trimmed)
				}
			}
		}

		if mainLine == "" {
			continue
		}

		node := parseTreeEntry(mainLine, 0)
		if node == nil || !strings.Contains(node.Name, root) {
			continue
		}
		if seen[node.Name] {
			continue
		}
		seen[node.Name] = true

		for _, cl := range childLines {
			child := parseTreeEntry(cl, 1)
			if child != nil && strings.Contains(child.Name, root) {
				node.Children = append(node.Children, child)
			}
		}

		roots = append(roots, node)
	}

	return roots
}

func hasFlatCum(line string) bool {
	return strings.Contains(line, "%") && (strings.Contains(line, "s ") || strings.Contains(line, "0 "))
}

var treeEntryRe = regexp.MustCompile(
	`^\s*(\S+)\s+(\S+%)\s+(\S+%)\s+(\S+)\s+(\S+%)\s*\|\s*(.+)$`,
)

var treeCalleeRe = regexp.MustCompile(
	`^\s*(\S+)\s+(\S+%)\s*\|\s*(.+)$`,
)

func parseTreeEntry(line string, depth int) *treeNode {
	// Try full entry format (main line).
	m := treeEntryRe.FindStringSubmatch(line)
	if m != nil {
		return &treeNode{
			FlatVal: m[1],
			FlatPct: parsePct(m[2]),
			CumVal:  m[4],
			CumPct:  parsePct(m[5]),
			Name:    strings.TrimSpace(m[6]),
			Depth:   depth,
		}
	}

	// Try callee format (indented line under main).
	m = treeCalleeRe.FindStringSubmatch(line)
	if m != nil {
		return &treeNode{
			CumVal: m[1],
			CumPct: parsePct(m[2]),
			Name:   strings.TrimSpace(m[3]),
			Depth:  depth,
		}
	}

	return nil
}

// ═══════════════════════════════════════════════════════════════════
// Caller/callee parsing from tree output
// ═══════════════════════════════════════════════════════════════════

type callerCalleeInfo struct {
	callers []callRef
	callees []callRef
}

type callRef struct {
	name string
	val  string
	pct  float64
}

func parseCallerCallee(treeOutput, root string) map[string]*callerCalleeInfo {
	result := make(map[string]*callerCalleeInfo)

	blocks := splitTreeBlocks(treeOutput)
	for _, block := range blocks {
		main, callers, callees := parseTreeBlock(block)
		if main == "" {
			continue
		}

		funcName := extractFuncName(main)
		if !strings.Contains(funcName, root) {
			continue
		}

		info := &callerCalleeInfo{}
		for _, c := range callers {
			name := extractFuncName(c.name)
			if strings.Contains(name, root) {
				info.callers = append(info.callers, c)
			}
		}
		for _, c := range callees {
			name := extractFuncName(c.name)
			if strings.Contains(name, root) {
				info.callees = append(info.callees, c)
			}
		}

		result[funcName] = info
	}

	return result
}

func splitTreeBlocks(output string) []string {
	// Split on lines that are all dashes/pluses.
	var blocks []string
	var current strings.Builder
	for _, line := range strings.Split(output, "\n") {
		trimmed := strings.TrimSpace(line)
		if len(trimmed) > 10 && strings.Count(trimmed, "-")+strings.Count(trimmed, "+") > len(trimmed)/2 {
			if current.Len() > 0 {
				blocks = append(blocks, current.String())
				current.Reset()
			}
			continue
		}
		current.WriteString(line)
		current.WriteByte('\n')
	}
	if current.Len() > 0 {
		blocks = append(blocks, current.String())
	}
	return blocks
}

var treeMainRe = regexp.MustCompile(
	`^\s*\S+\s+\S+%\s+\S+%\s+\S+\s+\S+%\s+\|\s+(.+)$`,
)

var treeRefRe = regexp.MustCompile(
	`^\s+(\S+)\s+(\S+%?)\s*\|\s+(.+)$`,
)

func parseTreeBlock(block string) (mainFunc string, callers, callees []callRef) {
	lines := strings.Split(block, "\n")
	mainIdx := -1

	for i, line := range lines {
		if treeMainRe.MatchString(line) {
			mainIdx = i
			m := treeMainRe.FindStringSubmatch(line)
			if m != nil {
				mainFunc = strings.TrimSpace(m[1])
			}
			break
		}
	}

	if mainIdx < 0 {
		return
	}

	// Lines before mainIdx are callers.
	for i := 0; i < mainIdx; i++ {
		m := treeRefRe.FindStringSubmatch(lines[i])
		if m != nil {
			callers = append(callers, callRef{
				name: strings.TrimSpace(m[3]),
				val:  m[1],
				pct:  parsePct(m[2]),
			})
		}
	}

	// Lines after mainIdx are callees.
	for i := mainIdx + 1; i < len(lines); i++ {
		m := treeRefRe.FindStringSubmatch(lines[i])
		if m != nil {
			callees = append(callees, callRef{
				name: strings.TrimSpace(m[3]),
				val:  m[1],
				pct:  parsePct(m[2]),
			})
		}
	}

	return
}

// ═══════════════════════════════════════════════════════════════════
// HTML generation (tabbed multi-view)
// ═══════════════════════════════════════════════════════════════════

func generateHTML(profPath, basePath, root, outPath string, topN int, minPct float64, detailFilter string) error {
	// Gather data for all tabs.
	cumEntries := mustRunPprof(profPath, "-functions", "-cum")
	cumFiltered := filterEntries(cumEntries, root, minPct)
	if len(cumFiltered) > topN {
		cumFiltered = cumFiltered[:topN]
	}

	flatEntries := mustRunPprof(profPath, "-functions", "-flat")
	flatFiltered := filterEntries(flatEntries, root, 0)
	sort.Slice(flatFiltered, func(i, j int) bool { return flatFiltered[i].FlatPct > flatFiltered[j].FlatPct })
	var bottlenecks []entry
	for _, e := range flatFiltered {
		if e.FlatPct >= minPct {
			bottlenecks = append(bottlenecks, e)
		}
	}
	if len(bottlenecks) > topN {
		bottlenecks = bottlenecks[:topN]
	}

	// Line-level entries for source heatmap.
	lineEntries := mustRunPprof(profPath, "-lines", "-cum")
	lineFiltered := filterEntries(lineEntries, root, minPct)
	if len(lineFiltered) > 60 {
		lineFiltered = lineFiltered[:60]
	}

	// Tree data.
	treeOut := mustRunPprofRaw(profPath, "-tree", "-cum", "-nodecount=50")
	treeNodes := parseTreeOutput(treeOut, root)

	// Function detail data (top 10 by flat).
	detailFuncs := getDetailFuncs(profPath, root, 10, minPct, detailFilter)

	// Max cum for color scaling.
	maxCum := 0.0
	for _, e := range cumFiltered {
		if e.CumPct > maxCum {
			maxCum = e.CumPct
		}
	}
	maxFlat := 0.0
	for _, e := range bottlenecks {
		if e.FlatPct > maxFlat {
			maxFlat = e.FlatPct
		}
	}

	f, err := os.Create(outPath)
	if err != nil {
		return err
	}
	defer f.Close()
	w := bufio.NewWriter(f)

	// Write HTML with CSS-only tabs (5 tabs now).
	fmt.Fprintf(w, `<!DOCTYPE html>
<html><head>
<meta charset="utf-8">
<title>Go Line Profiler</title>
<style>
:root { --bg: #1e1e2e; --bg2: #181825; --fg: #cdd6f4; --fg2: #a6adc8; --blue: #89b4fa; --red: #f38ba8; --green: #a6e3a1; --yellow: #f9e2af; --peach: #fab387; --border: #313244; }
body { font-family: 'Consolas','Monaco','Fira Code',monospace; font-size: 13px; background: var(--bg); color: var(--fg); margin: 0; padding: 20px; }
h1 { color: var(--blue); font-size: 22px; margin: 0 0 5px; }
.summary { color: var(--fg2); margin-bottom: 15px; font-size: 12px; }
/* Tabs */
.tabs { display: flex; gap: 0; border-bottom: 2px solid var(--border); margin-bottom: 15px; }
.tabs input[type="radio"] { display: none; }
.tabs label { padding: 8px 16px; cursor: pointer; color: var(--fg2); border-bottom: 2px solid transparent; margin-bottom: -2px; font-size: 13px; }
.tabs label:hover { color: var(--fg); }
.tab-content { display: none; }
#tab1:checked ~ .tabs label[for="tab1"],
#tab2:checked ~ .tabs label[for="tab2"],
#tab3:checked ~ .tabs label[for="tab3"],
#tab4:checked ~ .tabs label[for="tab4"],
#tab5:checked ~ .tabs label[for="tab5"] { color: var(--blue); border-bottom-color: var(--blue); }
#tab1:checked ~ #content1,
#tab2:checked ~ #content2,
#tab3:checked ~ #content3,
#tab4:checked ~ #content4,
#tab5:checked ~ #content5 { display: block; }
/* Tables */
table { width: 100%%; border-collapse: collapse; margin-bottom: 15px; }
th { text-align: left; color: var(--blue); padding: 5px 10px; border-bottom: 2px solid var(--border); font-size: 12px; }
td { padding: 4px 10px; font-size: 12px; }
tr:hover { background: rgba(137,180,250,0.04) !important; }
/* File sections */
.file-section { margin-bottom: 20px; border: 1px solid var(--border); border-radius: 6px; overflow: hidden; }
.file-header { background: var(--bg2); padding: 8px 12px; cursor: pointer; display: flex; justify-content: space-between; }
.file-header:hover { background: var(--bg); }
.file-name { color: var(--blue); font-weight: bold; }
.file-heat { color: var(--red); font-size: 11px; }
.file-body { display: block; max-height: 500px; overflow-y: auto; }
.file-body.collapsed { display: none; }
.ln { color: #585b70; text-align: right; padding: 0 8px; user-select: none; min-width: 45px; }
.annot { color: var(--yellow); text-align: right; padding: 0 6px; min-width: 110px; font-size: 11px; white-space: nowrap; }
.src { padding: 0 8px; white-space: pre; }
/* Tree */
.tree-node { padding: 2px 0; }
.tree-indent { color: #585b70; }
.tree-hot { color: var(--red); }
.tree-warm { color: var(--yellow); }
.tree-cool { color: var(--green); }
.tree-flat { color: var(--peach); font-size: 11px; }
/* Detail */
.detail-flat { color: var(--peach); text-align: right; min-width: 80px; padding: 0 4px; font-size: 11px; white-space: nowrap; }
.detail-cum { color: var(--yellow); text-align: right; min-width: 80px; padding: 0 4px; font-size: 11px; white-space: nowrap; }
</style>
</head><body>
<h1>Go Line Profiler</h1>
<div class="summary">%d functions | %d bottlenecks | %d detailed | root: %s</div>
<input type="radio" name="tab" id="tab1" checked>
<input type="radio" name="tab" id="tab2">
<input type="radio" name="tab" id="tab3">
<input type="radio" name="tab" id="tab4">
<input type="radio" name="tab" id="tab5">
<div class="tabs">
  <label for="tab1">Top Functions</label>
  <label for="tab2">Bottlenecks</label>
  <label for="tab3">Call Tree</label>
  <label for="tab4">File Heatmaps</label>
  <label for="tab5">Function Detail</label>
</div>
`, len(cumFiltered), len(bottlenecks), len(detailFuncs), html.EscapeString(root))

	// Tab 1: Top functions.
	fmt.Fprintf(w, `<div class="tab-content" id="content1">
<table><tr><th>#</th><th>flat</th><th>flat%%</th><th>cum</th><th>cum%%</th><th>function</th></tr>
`)
	for i, e := range cumFiltered {
		bg := heatBgCSS(e.CumPct, maxCum)
		fmt.Fprintf(w, `<tr style="background:%s"><td>%d</td><td>%s</td><td>%.1f%%</td><td>%s</td><td>%.1f%%</td><td>%s</td></tr>
`, bg, i+1, esc(e.FlatVal), e.FlatPct, esc(e.CumVal), e.CumPct, esc(shortName(e.Name)))
	}
	fmt.Fprintf(w, "</table></div>\n")

	// Tab 2: Bottlenecks.
	fmt.Fprintf(w, `<div class="tab-content" id="content2">
<table><tr><th>#</th><th>flat</th><th>flat%%</th><th>cum</th><th>cum%%</th><th>function</th></tr>
`)
	for i, e := range bottlenecks {
		bg := heatBgCSS(e.FlatPct, maxFlat)
		fmt.Fprintf(w, `<tr style="background:%s"><td>%d</td><td>%s</td><td>%.1f%%</td><td>%s</td><td>%.1f%%</td><td>%s</td></tr>
`, bg, i+1, esc(e.FlatVal), e.FlatPct, esc(e.CumVal), e.CumPct, esc(shortName(e.Name)))
	}
	fmt.Fprintf(w, "</table></div>\n")

	// Tab 3: Call tree.
	fmt.Fprintf(w, `<div class="tab-content" id="content3"><pre style="line-height:1.6">`)
	for _, n := range treeNodes {
		writeHTMLTreeNode(w, n, maxCum)
	}
	fmt.Fprintf(w, "</pre></div>\n")

	// Tab 4: File heatmaps.
	fmt.Fprintf(w, `<div class="tab-content" id="content4">`)
	writeFileHeatmaps(w, lineFiltered, root, maxCum)
	fmt.Fprintf(w, "</div>\n")

	// Tab 5: Function detail.
	fmt.Fprintf(w, `<div class="tab-content" id="content5">`)
	writeHTMLDetailFuncs(w, detailFuncs)
	fmt.Fprintf(w, "</div>\n")

	fmt.Fprintf(w, `<div class="summary" style="margin-top:20px">Generated by go-line-profiler</div>
</body></html>`)

	if err := w.Flush(); err != nil {
		return err
	}
	fmt.Printf("HTML written to %s (%d functions, %d bottlenecks, %d tree nodes, %d file entries, %d detailed)\n",
		outPath, len(cumFiltered), len(bottlenecks), len(treeNodes), len(lineFiltered), len(detailFuncs))
	return nil
}

func writeHTMLDetailFuncs(w *bufio.Writer, funcs []detailFunc) {
	if len(funcs) == 0 {
		fmt.Fprintf(w, `<p style="color:var(--fg2)">(no function detail data)</p>`)
		return
	}

	for i, fn := range funcs {
		collapsed := ""
		if i > 2 {
			collapsed = " collapsed"
		}

		// Find max flat for heat scaling within this function.
		maxFlatNs := 0.0
		for _, dl := range fn.Lines {
			if dl.FlatNs > maxFlatNs {
				maxFlatNs = dl.FlatNs
			}
		}

		shortN := shortFuncName(fn.Name)
		fmt.Fprintf(w, `<div class="file-section">
<div class="file-header" onclick="this.nextElementSibling.classList.toggle('collapsed')">
  <span class="file-name">%s</span>
  <span class="file-heat">%s flat, %s cum (%.1f%%)</span>
</div><div class="file-body%s"><table>
<tr><th style="width:80px">flat</th><th style="width:80px">cum</th><th style="width:50px">line</th><th>source</th></tr>
`, esc(shortN), esc(fn.FlatVal), esc(fn.CumVal), fn.TotalPct, collapsed)

		for _, dl := range fn.Lines {
			bg := "transparent"
			if maxFlatNs > 0 && dl.FlatNs > 0 {
				ratio := dl.FlatNs / maxFlatNs
				bg = heatBgCSSRatio(ratio)
			} else if dl.CumNs > 0 {
				bg = "rgba(166,227,161,0.06)" // subtle green for cum-only
			}
			fmt.Fprintf(w, `<tr style="background:%s"><td class="detail-flat">%s</td><td class="detail-cum">%s</td><td class="ln">%d</td><td class="src">%s</td></tr>
`, bg, esc(dl.Flat), esc(dl.Cum), dl.LineNo, esc(dl.Source))
		}

		fmt.Fprintf(w, "</table></div></div>\n")
	}
}

func writeHTMLTreeNode(w *bufio.Writer, n *treeNode, maxCum float64) {
	indent := strings.Repeat("  ", n.Depth)
	prefix := ""
	if n.Depth > 0 {
		prefix = "-> "
	}

	cls := "tree-cool"
	if n.CumPct > 20 {
		cls = "tree-hot"
	} else if n.CumPct > 5 {
		cls = "tree-warm"
	}

	name := shortFuncName(n.Name)
	cumStr := n.CumVal
	if cumStr == "" {
		cumStr = fmt.Sprintf("%.1f%%", n.CumPct)
	}

	flatNote := ""
	if n.FlatPct > 1 {
		flatNote = fmt.Sprintf(` <span class="tree-flat">[%.1f%% flat]</span>`, n.FlatPct)
	}

	fmt.Fprintf(w, `<span class="tree-indent">%s</span>%s<span class="%s">%s</span> (%s)%s
`, indent, prefix, cls, esc(name), esc(cumStr), flatNote)

	for _, child := range n.Children {
		writeHTMLTreeNode(w, child, maxCum)
	}
}

func writeFileHeatmaps(w *bufio.Writer, entries []entry, root string, maxCum float64) {
	files := make(map[string]*fileHeat)
	for _, e := range entries {
		if e.File == "" || e.Line == 0 {
			continue
		}
		fh, ok := files[e.File]
		if !ok {
			fh = &fileHeat{Path: e.File, Lines: make(map[int]*lineHeat)}
			files[e.File] = fh
		}
		fh.TotalCum += e.CumPct
		if lh, exists := fh.Lines[e.Line]; exists {
			lh.FlatPct += e.FlatPct
			lh.CumPct += e.CumPct
		} else {
			fh.Lines[e.Line] = &lineHeat{FlatPct: e.FlatPct, CumPct: e.CumPct}
		}
		if e.Line > fh.MaxLine {
			fh.MaxLine = e.Line
		}
	}

	for _, fh := range files {
		srcPath := findSourceFile(fh.Path, root)
		if srcPath != "" {
			data, err := os.ReadFile(srcPath)
			if err == nil {
				fh.Src = strings.Split(string(data), "\n")
				fh.SrcLoaded = true
			}
		}
	}

	sorted := make([]*fileHeat, 0, len(files))
	for _, fh := range files {
		sorted = append(sorted, fh)
	}
	sort.Slice(sorted, func(i, j int) bool { return sorted[i].TotalCum > sorted[j].TotalCum })

	for i, fh := range sorted {
		collapsed := ""
		if i > 2 {
			collapsed = " collapsed"
		}
		fmt.Fprintf(w, `<div class="file-section">
<div class="file-header" onclick="this.nextElementSibling.classList.toggle('collapsed')">
  <span class="file-name">%s</span>
  <span class="file-heat">%.1f%% total</span>
</div><div class="file-body%s"><table>
`, esc(fh.Path), fh.TotalCum, collapsed)

		if fh.SrcLoaded {
			minLine, maxLine := computeLineRange(fh)
			for ln := minLine; ln <= maxLine && ln <= len(fh.Src); ln++ {
				lh := fh.Lines[ln]
				bg, annot := "", ""
				if lh != nil {
					bg = fmt.Sprintf(` style="background:%s"`, heatBgCSS(lh.CumPct, maxCum))
					annot = fmt.Sprintf("%.1f%% cum, %.1f%% flat", lh.CumPct, lh.FlatPct)
				}
				src := ""
				if ln-1 < len(fh.Src) {
					src = fh.Src[ln-1]
				}
				fmt.Fprintf(w, "<tr%s><td class=\"ln\">%d</td><td class=\"annot\">%s</td><td class=\"src\">%s</td></tr>\n",
					bg, ln, annot, esc(src))
			}
		} else {
			lineNums := make([]int, 0, len(fh.Lines))
			for ln := range fh.Lines {
				lineNums = append(lineNums, ln)
			}
			sort.Ints(lineNums)
			for _, ln := range lineNums {
				lh := fh.Lines[ln]
				bg := fmt.Sprintf(` style="background:%s"`, heatBgCSS(lh.CumPct, maxCum))
				fmt.Fprintf(w, "<tr%s><td class=\"ln\">%d</td><td class=\"annot\">%.1f%% cum</td><td class=\"src\">(source not found)</td></tr>\n",
					bg, ln, lh.CumPct)
			}
		}
		fmt.Fprintf(w, "</table></div></div>\n")
	}
}

// ═══════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════

func esc(s string) string { return html.EscapeString(s) }

func sectionHeader(title string) {
	bar := strings.Repeat("=", 60)
	fmt.Printf("\n\033[96m%s\033[0m\n\033[96m%s\033[0m\n\n", bar, title)
}

func printEntryTable(entries []entry) {
	if len(entries) == 0 {
		fmt.Println("  (no entries)")
		return
	}
	maxCum := entries[0].CumPct
	for i, e := range entries {
		color := heatColor(e.CumPct, maxCum)
		reset := "\033[0m"
		name := shortName(e.Name)
		fmt.Printf("  %s%2d. %-40s  %8s (%5.1f%%)  cum %8s (%5.1f%%)%s\n",
			color, i+1, name, e.FlatVal, e.FlatPct, e.CumVal, e.CumPct, reset)
	}
	fmt.Println()
}

// shortName extracts a readable short name from a pprof entry.
func shortName(name string) string {
	// Remove full paths, keep package.Function and file:line.
	name = strings.TrimSuffix(name, " (inline)")

	// For function entries like "bulletgo/internal/engine.(*GameEngine).updatePlaying"
	// extract just the receiver.method part.
	if idx := strings.LastIndex(name, "/"); idx >= 0 {
		name = name[idx+1:]
	}

	if len(name) > 55 {
		name = name[:52] + "..."
	}
	return name
}

// shortFuncName extracts a short function name.
func shortFuncName(name string) string {
	name = strings.TrimSuffix(name, " (inline)")
	// Remove file path after function name.
	if idx := strings.Index(name, " "); idx > 0 {
		// Check if what follows is a file path.
		rest := strings.TrimSpace(name[idx:])
		if strings.Contains(rest, ".go:") || strings.Contains(rest, "/") {
			name = name[:idx]
		}
	}
	// Shorten package path.
	if idx := strings.LastIndex(name, "/"); idx >= 0 {
		name = name[idx+1:]
	}
	if len(name) > 50 {
		name = name[:47] + "..."
	}
	return name
}

// extractFuncName gets the fully-qualified function name without file path.
func extractFuncName(name string) string {
	name = strings.TrimSuffix(name, " (inline)")
	// Remove trailing file path.
	parts := strings.Fields(name)
	if len(parts) >= 1 {
		return parts[0]
	}
	return name
}

func detectModulePath() string {
	data, err := os.ReadFile("go.mod")
	if err != nil {
		dir, _ := os.Getwd()
		for i := 0; i < 5; i++ {
			dir = filepath.Dir(dir)
			data, err = os.ReadFile(filepath.Join(dir, "go.mod"))
			if err == nil {
				break
			}
		}
		if err != nil {
			return ""
		}
	}
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "module ") {
			return strings.TrimSpace(strings.TrimPrefix(line, "module"))
		}
	}
	return ""
}

var fileLineRe = regexp.MustCompile(`(\S+\.go):(\d+)`)

func extractFileLine(name string) (string, int) {
	m := fileLineRe.FindStringSubmatch(name)
	if m != nil {
		line, _ := strconv.Atoi(m[2])
		return m[1], line
	}
	return name, 0
}

func parsePct(s string) float64 {
	s = strings.TrimSuffix(s, "%")
	v, _ := strconv.ParseFloat(s, 64)
	return v
}

func filterEntries(entries []entry, root string, minPct float64) []entry {
	if root == "" && minPct <= 0 {
		return entries
	}
	var out []entry
	for _, e := range entries {
		if e.CumPct < minPct && e.FlatPct < minPct {
			continue
		}
		if root != "" && !strings.Contains(e.Name, root) {
			continue
		}
		out = append(out, e)
	}
	return out
}

func heatColor(pct, maxPct float64) string {
	if maxPct <= 0 {
		return ""
	}
	ratio := pct / maxPct
	switch {
	case ratio > 0.7:
		return "\033[91m"
	case ratio > 0.4:
		return "\033[93m"
	case ratio > 0.2:
		return "\033[33m"
	default:
		return "\033[32m"
	}
}

func heatBgCSS(pct, maxPct float64) string {
	if maxPct <= 0 || pct <= 0 {
		return "transparent"
	}
	ratio := pct / maxPct
	if ratio > 1 {
		ratio = 1
	}
	return heatBgCSSRatio(ratio)
}

func heatBgCSSRatio(ratio float64) string {
	if ratio <= 0 {
		return "transparent"
	}
	switch {
	case ratio > 0.7:
		alpha := 0.15 + (ratio-0.7)/0.3*0.25
		return fmt.Sprintf("rgba(243,139,168,%.2f)", alpha)
	case ratio > 0.4:
		alpha := 0.08 + (ratio-0.4)/0.3*0.12
		return fmt.Sprintf("rgba(250,179,135,%.2f)", alpha)
	case ratio > 0.15:
		alpha := 0.04 + (ratio-0.15)/0.25*0.08
		return fmt.Sprintf("rgba(249,226,175,%.2f)", alpha)
	default:
		return "transparent"
	}
}

func computeLineRange(fh *fileHeat) (int, int) {
	const context = 5
	minLine := math.MaxInt32
	maxLine := 0
	for ln := range fh.Lines {
		if ln-context < minLine {
			minLine = ln - context
		}
		if ln+context > maxLine {
			maxLine = ln + context
		}
	}
	if minLine < 1 {
		minLine = 1
	}
	return minLine, maxLine
}

func findSourceFile(pprofPath, root string) string {
	if _, err := os.Stat(pprofPath); err == nil {
		return pprofPath
	}
	cwd, _ := os.Getwd()
	candidates := []string{filepath.Join(cwd, pprofPath)}
	if root != "" {
		if idx := strings.Index(pprofPath, root); idx > 0 {
			relPath := pprofPath[idx+len(root):]
			relPath = strings.TrimPrefix(relPath, "/")
			relPath = strings.TrimPrefix(relPath, "\\")
			candidates = append(candidates, filepath.Join(cwd, relPath))
		}
	}
	gopath := os.Getenv("GOPATH")
	if gopath == "" {
		home, _ := os.UserHomeDir()
		gopath = filepath.Join(home, "go")
	}
	candidates = append(candidates, filepath.Join(gopath, "pkg", "mod", pprofPath))
	for _, c := range candidates {
		if _, err := os.Stat(c); err == nil {
			return c
		}
	}
	return ""
}
