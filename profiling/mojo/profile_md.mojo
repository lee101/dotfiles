"""Token-bounded TensorRT profiler log to Markdown converter.

The large, line-oriented scan and hotspot ranking stay in Mojo. File access is
provided by Mojo's standard library, so the compiled binary has no Python
runtime dependency.
"""

from std.collections import List
from std.sys import argv


comptime USAGE = String(
    "profile-md (Mojo core) - compact TensorRT profiler reports\n"
    "\n"
    "Usage: profile-md INPUT [--out PATH] [--top N] [--max-chars N]\n"
    "\n"
    "The wrapper delegates Nsight .nsys-rep/.ncu-rep files to the compatible\n"
    "Python backend. This native core handles TensorRT .log/.txt inputs.\n"
)


@fieldwise_init
struct Layer(Copyable, Movable):
    var name: String
    var time_ms: Float64


@fieldwise_init
struct Options(Copyable, Movable):
    var input: String
    var output: String
    var top: Int
    var max_chars: Int


@fieldwise_init
struct Summary(Copyable, Movable):
    var throughput: Float64
    var latency_mean: Float64
    var latency_p90: Float64
    var enqueue_mean: Float64
    var gpu_mean: Float64
    var h2d_mean: Float64
    var d2h_mean: Float64


def parse_options() raises -> Options:
    var args = argv()
    if len(args) < 2:
        print(USAGE)
        raise Error("missing input file")
    var input = String("")
    var output = String("")
    var top = 20
    var max_chars = 12_000
    var compact = False
    var top_set = False
    var max_chars_set = False
    var i = 1
    while i < len(args):
        var arg = String(args[i])
        if arg == "-h" or arg == "--help":
            print(USAGE)
            return Options("", "", 0, 0)
        elif arg == "--out":
            i += 1
            if i >= len(args):
                raise Error("--out requires a path")
            output = String(args[i])
        elif arg == "--top":
            i += 1
            if i >= len(args):
                raise Error("--top requires an integer")
            top = Int(atol(String(args[i])))
            top_set = True
        elif arg == "--max-chars":
            i += 1
            if i >= len(args):
                raise Error("--max-chars requires an integer")
            max_chars = Int(atol(String(args[i])))
            max_chars_set = True
        elif arg == "--compact":
            compact = True
        elif arg == "--kind":
            i += 1
            if i >= len(args):
                raise Error("--kind requires a value")
            var kind = String(args[i])
            if kind != "auto" and kind != "trtexec":
                raise Error("Mojo core only accepts --kind auto|trtexec")
        elif arg.startswith("--kind="):
            var kind = slice_after(arg, "--kind=")
            if kind != "auto" and kind != "trtexec":
                raise Error("Mojo core only accepts --kind auto|trtexec")
        elif arg.startswith("-"):
            raise Error("unknown option: " + arg)
        elif input.byte_length() == 0:
            input = arg
        else:
            raise Error("only one input file is accepted")
        i += 1
    if input.byte_length() == 0:
        raise Error("missing input file")
    if compact and not top_set:
        top = 10
    if compact and not max_chars_set:
        max_chars = 6_000
    if top < 1:
        raise Error("--top must be positive")
    if max_chars < 1_000:
        raise Error("--max-chars must be at least 1000")
    return Options(input, output, top, max_chars)


def read_text(path: String) raises -> String:
    with open(path, "r") as handle:
        return handle.read()


def write_text(path: String, text: String) raises:
    with open(path, "w") as handle:
        handle.write(text)


def slice_after(line: String, marker: String) -> String:
    var position = line.find(marker)
    if position < 0:
        return ""
    return String(
        String(line[byte = position + marker.byte_length() :]).strip()
    )


def has_digit(value: String) -> Bool:
    for i in range(value.byte_length()):
        var char = value[byte=i]
        if char >= "0" and char <= "9":
            return True
    return False


def first_number(value: String) raises -> Float64:
    for raw in value.split(" "):
        var token = String(String(raw).strip(" \t,;()[]"))
        if has_digit(token):
            return Float64(atof(token))
    return -1.0


def value_after(line: String, marker: String) raises -> Float64:
    var tail = slice_after(line, marker)
    if tail.byte_length() == 0:
        return -1.0
    return first_number(tail)


def metric_mean(line: String) raises -> Float64:
    var value = value_after(line, "mean =")
    if value >= 0.0:
        return value
    return value_after(line, "mean=")


def metric_p90(line: String) raises -> Float64:
    var value = value_after(line, "percentile(90%) =")
    if value >= 0.0:
        return value
    return value_after(line, "p90 =")


def clean_label(value: String, limit: Int = 100) -> String:
    var label = String(value.strip(" \t:-"))
    # Markdown tables must remain one physical line.
    label = label.replace("|", "\\|")
    label = label.replace("`", "'")
    if label.byte_length() <= limit:
        return label
    return String(label[byte = 0 : limit - 3]) + "..."


def layer_from_line(line: String) raises -> Layer:
    var body = slice_after(line, "[TRT]")
    if body.byte_length() == 0 or body.find(" ms") < 0:
        return Layer("", -1.0)
    if (
        body.find("Throughput:") >= 0
        or body.find("Latency:") >= 0
        or body.find("Enqueue Time:") >= 0
        or body.find("H2D Latency:") >= 0
        or body.find("GPU Compute Time:") >= 0
        or body.find("D2H Latency:") >= 0
        or body.find("Total Host Walltime:") >= 0
        or body.find("Total GPU Compute Time:") >= 0
    ):
        return Layer("", -1.0)

    var marker = body.find(" ms")
    var prefix = String(String(body[byte=0:marker]).strip())
    var split = prefix.rfind(" ")
    if split < 1:
        return Layer("", -1.0)
    var raw_time = String(prefix[byte = split + 1 :])
    if not has_digit(raw_time):
        return Layer("", -1.0)
    var name = clean_label(String(prefix[byte=0:split]))
    if name.byte_length() == 0:
        return Layer("", -1.0)
    return Layer(name, Float64(atof(raw_time)))


def insert_ranked(mut layers: List[Layer], layer: Layer, limit: Int):
    if len(layers) < limit:
        layers.append(layer.copy())
    elif layers[len(layers) - 1].time_ms < layer.time_ms:
        layers[len(layers) - 1] = layer.copy()
    else:
        return
    var position = len(layers) - 1
    while (
        position > 0 and layers[position - 1].time_ms < layers[position].time_ms
    ):
        var previous = layers[position - 1].copy()
        layers[position - 1] = layers[position].copy()
        layers[position] = previous^
        position -= 1


def parse(
    text: String, top: Int
) raises -> Tuple[Summary, List[Layer], Int, Int]:
    var summary = Summary(-1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0)
    var layers = List[Layer]()
    var warning_count = 0
    var line_count = 0
    for raw in text.split("\n"):
        line_count += 1
        var line = String(String(raw).strip())
        if line.byte_length() == 0:
            continue
        if line.find("[TRT]") >= 0:
            if line.find("Throughput:") >= 0:
                summary.throughput = value_after(line, "Throughput:")
            elif line.find("Latency:") >= 0:
                summary.latency_mean = metric_mean(line)
                summary.latency_p90 = metric_p90(line)
            elif line.find("Enqueue Time:") >= 0:
                summary.enqueue_mean = metric_mean(line)
            elif line.find("GPU Compute Time:") >= 0:
                summary.gpu_mean = metric_mean(line)
            elif line.find("H2D Latency:") >= 0:
                summary.h2d_mean = metric_mean(line)
            elif line.find("D2H Latency:") >= 0:
                summary.d2h_mean = metric_mean(line)
            var lowered = line.lower()
            if (
                lowered.find("warning") >= 0
                or lowered.find("error") >= 0
                or lowered.find("failed") >= 0
            ):
                warning_count += 1
        var layer = layer_from_line(line)
        if layer.time_ms >= 0.0:
            insert_ranked(layers, layer, top)
    return (summary^, layers^, warning_count, line_count)


def metric_line(label: String, value: Float64, unit: String = "ms") -> String:
    if value < 0.0:
        return ""
    return "- " + label + ": " + String(value) + " " + unit + "\n"


def render(
    source: String,
    summary: Summary,
    layers: List[Layer],
    warnings: Int,
    scanned: Int,
    max_chars: Int,
) -> String:
    var out = String("# TensorRT trtexec Report\n\n")
    out += "- Source: `" + source.replace("`", "'") + "`\n"
    out += "- Scanned: " + String(scanned) + " lines\n"
    out += "- Retained hotspots: " + String(len(layers)) + "\n"
    out += "- Warning/error lines: " + String(warnings) + "\n\n"
    out += "## Performance Summary\n\n"
    if summary.throughput >= 0.0:
        out += metric_line("Throughput", summary.throughput, "qps")
    out += metric_line("Latency mean", summary.latency_mean)
    out += metric_line("Latency p90", summary.latency_p90)
    out += metric_line("Enqueue mean", summary.enqueue_mean)
    out += metric_line("GPU compute mean", summary.gpu_mean)
    out += metric_line("H2D mean", summary.h2d_mean)
    out += metric_line("D2H mean", summary.d2h_mean)
    if summary.throughput < 0.0 and summary.latency_mean < 0.0:
        out += "No TensorRT performance summary was found.\n"

    if len(layers) > 0:
        out += "\n## Per-Layer Runtime\n\n"
        out += "| Layer | Time (ms) |\n|---|---:|\n"
        for layer in layers:
            var row = (
                "| `" + layer.name + "` | " + String(layer.time_ms) + " |\n"
            )
            if out.byte_length() + row.byte_length() + 160 > max_chars:
                out += "\n_Output capped by `--max-chars`._\n"
                break
            out += row

    out += "\n## Next action\n\n"
    if len(layers) > 0:
        out += (
            "- Profile or optimize `"
            + layers[0].name
            + "` first; it is the hottest retained layer.\n"
        )
    elif warnings > 0:
        out += (
            "- Inspect the warning/error lines; no per-layer timings were"
            " parsed.\n"
        )
    else:
        out += (
            "- Re-run trtexec with `--dumpProfile` to capture per-layer"
            " timings.\n"
        )
    return out


def main() raises:
    var options = parse_options()
    if options.input.byte_length() == 0:
        return
    var text = read_text(options.input)
    var parsed = parse(text, options.top)
    var markdown = render(
        options.input,
        parsed[0],
        parsed[1],
        parsed[2],
        parsed[3],
        options.max_chars,
    )
    if options.output.byte_length() > 0:
        write_text(options.output, markdown)
        print("Wrote markdown report to", options.output)
    else:
        print(markdown, end="")
