package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
)

type node struct {
	dirs  map[string]*node
	files []string
}

func newNode() *node { return &node{dirs: map[string]*node{}} }

type opts struct {
	all        bool // include gitignored
	depth      int  // max depth, 0 = unlimited
	color      bool
	dirsOnly   bool
	slash      bool // re-append trailing / to dirs
	noCompress bool // disable single-child chain folding
}

func main() {
	o := opts{depth: 0, color: useColor()}
	root := "."
	for i := 1; i < len(os.Args); i++ {
		a := os.Args[i]
		switch {
		case a == "-a" || a == "--all":
			o.all = true
		case a == "-d" || a == "--dirs":
			o.dirsOnly = true
		case a == "--no-color":
			o.color = false
		case a == "-C" || a == "--color":
			o.color = true
		case a == "--slash":
			o.slash = true
		case a == "--no-compress":
			o.noCompress = true
		case a == "-L":
			i++
			if i < len(os.Args) {
				fmt.Sscanf(os.Args[i], "%d", &o.depth)
			}
		case strings.HasPrefix(a, "-L"):
			fmt.Sscanf(a[2:], "%d", &o.depth)
		case a == "-h" || a == "--help":
			usage()
			return
		default:
			root = a
		}
	}

	paths, err := list(root, o)
	if err != nil {
		fmt.Fprintln(os.Stderr, "gtree:", err)
		os.Exit(1)
	}
	tree := newNode()
	for _, p := range paths {
		insert(tree, strings.Split(p, "/"))
	}
	var b strings.Builder
	render(&b, tree, 0, o)
	fmt.Print(b.String())
}

func usage() {
	fmt.Print(`gtree - token-efficient, gitignore-aware tree

Each line is one dir: first token = dir name, rest = its files.
Nested dirs are indented; single-child chains fold (a/b/c).

usage: gtree [path] [opts]
  -a, --all      include gitignored files
  -d, --dirs     directories only
  -L N           max depth
  --slash        re-append trailing / to dirs
  --no-compress  don't fold single-child dir chains
  --no-color     disable color
  -h             help
`)
}

func insert(n *node, parts []string) {
	if len(parts) == 1 {
		n.files = append(n.files, parts[0])
		return
	}
	d := parts[0]
	if n.dirs[d] == nil {
		n.dirs[d] = newNode()
	}
	insert(n.dirs[d], parts[1:])
}

func render(b *strings.Builder, n *node, depth int, o opts) {
	if o.depth > 0 && depth > o.depth {
		return
	}
	// root files share line 0
	if depth == 0 && !o.dirsOnly && len(n.files) > 0 {
		sort.Strings(n.files)
		for i, f := range n.files {
			if i > 0 {
				b.WriteByte(' ')
			}
			b.WriteString(colorFile(f, o.color))
		}
		b.WriteByte('\n')
	}
	for _, d := range sortedKeys(n.dirs) {
		renderDir(b, d, n.dirs[d], depth, o)
	}
}

// renderDir prints "dirname file1 file2..." then recurses into subdirs.
func renderDir(b *strings.Builder, name string, n *node, depth int, o opts) {
	if o.depth > 0 && depth >= o.depth {
		return
	}
	// fold single-child dir chains: a -> a/b -> a/b/c
	for !o.noCompress && len(n.files) == 0 && len(n.dirs) == 1 {
		for k, v := range n.dirs {
			name, n = name+"/"+k, v
		}
	}
	b.WriteString(strings.Repeat(" ", depth))
	b.WriteString(colorDir(name, o))
	if !o.dirsOnly {
		sort.Strings(n.files)
		for _, f := range n.files {
			b.WriteByte(' ')
			b.WriteString(colorFile(f, o.color))
		}
	}
	b.WriteByte('\n')
	for _, d := range sortedKeys(n.dirs) {
		renderDir(b, d, n.dirs[d], depth+1, o)
	}
}

func sortedKeys(m map[string]*node) []string {
	ks := make([]string, 0, len(m))
	for k := range m {
		ks = append(ks, k)
	}
	sort.Strings(ks)
	return ks
}

// list returns file paths relative to root, "/"-separated.
func list(root string, o opts) ([]string, error) {
	st, err := os.Stat(root)
	if err != nil {
		return nil, err
	}
	if !st.IsDir() {
		return []string{filepath.Base(root)}, nil
	}
	if !o.all {
		if ps, ok := gitList(root); ok {
			return ps, nil
		}
	}
	return walkList(root, o)
}

func gitList(root string) ([]string, bool) {
	cmd := exec.Command("git", "-C", root, "ls-files", "--cached", "--others", "--exclude-standard")
	out, err := cmd.Output()
	if err != nil {
		return nil, false
	}
	lines := strings.Split(strings.TrimRight(string(out), "\n"), "\n")
	res := make([]string, 0, len(lines))
	for _, l := range lines {
		if l != "" {
			res = append(res, l)
		}
	}
	return res, true
}

func walkList(root string, o opts) ([]string, error) {
	var res []string
	err := filepath.WalkDir(root, func(p string, d os.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		name := d.Name()
		if p == root {
			return nil
		}
		if d.IsDir() && (name == ".git" || name == "node_modules" || name == ".venv" || name == "__pycache__") {
			return filepath.SkipDir
		}
		if d.IsDir() {
			return nil
		}
		rel, _ := filepath.Rel(root, p)
		res = append(res, filepath.ToSlash(rel))
		return nil
	})
	return res, err
}

func useColor() bool {
	if os.Getenv("NO_COLOR") != "" {
		return false
	}
	fi, _ := os.Stdout.Stat()
	return fi != nil && fi.Mode()&os.ModeCharDevice != 0
}

func colorDir(s string, o opts) string {
	if o.slash {
		s += "/"
	}
	if !o.color {
		return s
	}
	return "\x1b[1;34m" + s + "\x1b[0m"
}

func colorFile(s string, c bool) string {
	if !c {
		return s
	}
	code := extColor(s)
	if code == "" {
		return s
	}
	return "\x1b[" + code + "m" + s + "\x1b[0m"
}

func extColor(s string) string {
	ext := strings.ToLower(filepath.Ext(s))
	switch ext {
	case ".go", ".rs", ".c", ".h", ".cpp", ".java", ".py", ".rb", ".ts", ".tsx", ".js", ".jsx", ".lua", ".sh", ".bash":
		return "33" // yellow: source
	case ".json", ".toml", ".yaml", ".yml", ".ini", ".cfg", ".conf", ".env":
		return "36" // cyan: config
	case ".md", ".txt", ".rst", ".org":
		return "37" // grey: docs
	case ".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp", ".ico", ".mp4", ".mov", ".pdf":
		return "35" // magenta: media
	case ".zip", ".tar", ".gz", ".tgz", ".xz", ".zst", ".7z", ".bin", ".o", ".a", ".so":
		return "31" // red: binary/archive
	}
	if strings.HasPrefix(s, ".") {
		return "90" // dim: dotfile
	}
	return ""
}
