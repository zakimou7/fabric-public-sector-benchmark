"""Volume-controlled throughput of registerCertificate."""
import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "figures")
os.makedirs(OUT, exist_ok=True)

n = [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000]
tput = [137.7, 177.0, 264.2, 237.0, 239.5, 232.3, 227.3, 205.8, 203.9, 194.9]

fig, ax = plt.subplots(figsize=(7, 3.8))
ax.plot(n, tput, color="teal", lw=2, marker="o", label="Throughput")
ax.set_xlabel("Number of transactions")
ax.set_ylabel("Throughput (TPS)")
ax.set_xlim(0, 11000)
ax.set_ylim(100, 300)
ax.grid(True, alpha=0.4)
ax.set_title("Throughput of registerCertificate (volume-controlled)")
ax.legend(loc="lower right", edgecolor="black")
fig.tight_layout()
fig.savefig(os.path.join(OUT, "vol_thr.png"), dpi=300)
print("saved vol_thr.png")
