# Quick Command Sets (THM + Docker)

Use only authorized targets.

## TryHackMe (AttackBox)

```bash
nmap -h
# Shows Nmap help and available options.

ip a
# Shows your AttackBox network interfaces and IPs.

ping -c 1 10.64.176.44
# Quick check that the assigned target machine is reachable.

nmap -n -sT -Pn --open -p 22,80,443,3389 <MACHINE_IP>
# Small, clear open-port scan for demo use.

nmap -n -sT -Pn -sV --version-light -p 22,80,443,3389 <MACHINE_IP>
# Light service/version check on the same ports.

nmap -n -sT -Pn -sC -sV -p 22,80,443,3389,3306 <MACHINE_IP>
# Runs default NSE scripts + service detection for richer recon.
```

## Docker Lab (Local)

```bash
cd docker-lab
docker compose -f docker-compose.yml -f docker-compose.expanded.yml up -d --build
docker compose -f docker-compose.yml -f docker-compose.expanded.yml ps
# Starts and checks your expanded local lab.

docker compose -f docker-compose.yml -f docker-compose.expanded.yml exec -T scanner nmap -sn 172.28.0.0/24
# Discovers live lab hosts.

docker compose -f docker-compose.yml -f docker-compose.expanded.yml exec -T scanner nmap -sT -n --open -p- 172.28.0.0/24
# Full open-port scan across the Docker lab subnet without a static port list.

finally recreate 👍:
|cd docker-lab
docker compose -f docker-compose.yml -f docker-compose.expanded.yml up -d --no-deps --force-recreate mariadb-demo

