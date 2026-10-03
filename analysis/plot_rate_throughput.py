"""Rate-controlled throughput of registerCertificate."""
import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "figures")
os.makedirs(OUT, exist_ok=True)

rate = [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000]
tput = [97.1, 137.4, 185.7, 130.4, 138.4, 187.4, 151.1, 149.8, 149.0, 160.3]

fig, ax = plt.subplots(figsize=(7, 3.8))
ax.plot(rate, tput, color="blue", lw=2, marker="o", label="Throughput")
ax.set_xlabel("Target send rate (TPS)")
ax.set_ylabel("Throughput (TPS)")
ax.set_xlim(0, 1100)
ax.set_ylim(80, 210)
ax.grid(True, alpha=0.4)
ax.set_title("Throughput of registerCertificate under rate control")
fig.tight_layout()
fig.savefig(os.path.join(OUT, "thr_rate.png"), dpi=300)
print("saved thr_rate.png")
