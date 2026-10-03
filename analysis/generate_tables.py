"""Generate CSV and LaTeX tables for the rate- and volume-controlled benchmarks."""
import csv
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tables")
os.makedirs(OUT, exist_ok=True)

rate = {
    "Target rate (TPS)": [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000],
    "Throughput (TPS)": [97.1, 137.4, 185.7, 130.4, 138.4, 187.4, 151.1, 149.8, 149.0, 160.3],
    "Avg latency (s)": [0.76, 2.41, 1.14, 5.55, 5.14, 2.65, 5.05, 5.30, 5.14, 4.85],
    "Max latency (s)": [2.16, 4.04, 2.81, 6.85, 6.25, 5.29, 5.89, 5.99, 5.91, 5.55],
}
volume = {
    "Transactions": [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000],
    "Throughput (TPS)": [137.7, 177.0, 264.2, 237.0, 239.5, 232.3, 227.3, 205.8, 203.9, 194.9],
    "Avg latency (s)": [5.48, 7.29, 5.22, 10.28, 12.97, 16.29, 20.32, 25.59, 30.25, 35.59],
    "Max latency (s)": [6.72, 9.96, 7.41, 13.58, 17.64, 21.52, 27.59, 32.84, 38.71, 44.54],
}


def rows(data):
    cols = list(data)
    return cols, list(zip(*data.values()))


def fmt(v):
    return str(v) if isinstance(v, int) else f"{v:.2f}" if v < 100 and False else (f"{v:.1f}" if "." in str(v) and abs(v) >= 50 else f"{v:.2f}")


def write(name, data, caption, label):
    cols, body = rows(data)
    with open(os.path.join(OUT, f"{name}.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(cols)
        w.writerows(body)
    with open(os.path.join(OUT, f"{name}.tex"), "w") as f:
        f.write("\\begin{table}[htbp]\n\\centering\n")
        f.write(f"\\caption{{{caption}}}\\label{{{label}}}\n")
        f.write("\\begin{tabular}{" + "r" * len(cols) + "}\n\\toprule\n")
        f.write(" & ".join(cols) + " \\\\\n\\midrule\n")
        for r in body:
            f.write(" & ".join(fmt(v) for v in r) + " \\\\\n")
        f.write("\\bottomrule\n\\end{tabular}\n\\end{table}\n")
    print(f"saved {name}.csv / {name}.tex")


write("rate_controlled", rate,
      "Rate-controlled benchmark results for \\texttt{registerCertificate}.", "tab:rate")
write("volume_controlled", volume,
      "Volume-controlled benchmark results for \\texttt{registerCertificate}.", "tab:volume")
