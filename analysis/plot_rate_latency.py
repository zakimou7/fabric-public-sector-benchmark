"""Rate-controlled latency of registerCertificate."""
import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "figures")
os.makedirs(OUT, exist_ok=True)

rate = [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000]
max_lat = [2.16, 4.04, 2.81, 6.85, 6.25, 5.29, 5.89, 5.99, 5.91, 5.55]
avg_lat = [0.76, 2.41, 1.14, 5.55, 5.14, 2.65, 5.05, 5.30, 5.14, 4.85]

fig, ax = plt.subplots(figsize=(7, 3.8))
ax.plot(rate, max_lat, color="red", lw=2, marker="^", label="Max latency")
ax.plot(rate, avg_lat, color="blue", lw=2, marker="s", label="Average latency")
ax.set_xlabel("Target send rate (TPS)")
ax.set_ylabel("Latency (s)")
ax.set_xlim(0, 1100)
ax.set_ylim(0, 8)
ax.grid(True, alpha=0.4)
ax.set_title("Latency of registerCertificate under rate control")
ax.legend(loc="upper left", fontsize=8, edgecolor="black")
fig.tight_layout()
fig.savefig(os.path.join(OUT, "lat_rate.png"), dpi=300)
print("saved lat_rate.png")
