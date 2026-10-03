"""Volume-controlled latency of registerCertificate."""
import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "figures")
os.makedirs(OUT, exist_ok=True)

n = [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000]
avg_lat = [5.48, 7.29, 5.22, 10.28, 12.97, 16.29, 20.32, 25.59, 30.25, 35.59]
max_lat = [6.72, 9.96, 7.41, 13.58, 17.64, 21.52, 27.59, 32.84, 38.71, 44.54]

fig, ax = plt.subplots(figsize=(7, 3.8))
ax.plot(n, avg_lat, color="blue", lw=2, marker="^", label="Avg latency")
ax.plot(n, max_lat, color="red", lw=2, marker="s", label="Max latency")
ax.set_xlabel("Number of transactions")
ax.set_ylabel("Latency (s)")
ax.set_xlim(0, 11000)
ax.set_ylim(0, 50)
ax.grid(True, alpha=0.4)
ax.set_title("Latency of registerCertificate (volume-controlled)")
ax.legend(loc="upper left", edgecolor="black")
fig.tight_layout()
fig.savefig(os.path.join(OUT, "vol_lat.png"), dpi=300)
print("saved vol_lat.png")
