#!/usr/bin/env python3
import subprocess
import json
import sys
import os
import datetime #to geerate timestamps
import socket #to grab the machines hostname
import getpass #to grab the user running the script

#Defining the set points
MAX_DISK_PERCENT = 80
MAX_MEM_PERCENT = 85
MAX_CPU_PERCENT = 90

#Defining the path to the log file
LOG_FILE = "/var/log/infra_analyzer.log"

# Dynamically resolve absolute paths to make the script cron-safe
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BASH_SCRIPT = os.path.join(SCRIPT_DIR, 'gather_metrics.sh')

#function to fetch the metrics from the bash script
def fetch_metrics():
    try:
        results = subprocess.run(
            [BASH_SCRIPT],
            capture_output=True,
            text=True,
            check=True
        )
        
    except FileNotFoundError:
        #if the file './gather_metrics.sh' does not exist, Python jumps here
        print("Error: The script gather_metrics.sh is missing!")
        sys.exit(1)
        
    except subprocess.CalledProcessError:
        #If the script exists but crashes/fails internally, Python jumps here
        print("Error: the script failed to execute properly!")
        sys.exit(1)
        
    """Data Parsing: Extarcting the stdout from the subprocess result,
    Using json.loads() to convert that string into a native python dictionary,
    Returning that dictionary"""
    
    parsed_data = json.loads(results.stdout)
    return parsed_data

    
def analyze_metrics(data):
    alerts = []
    if data['Disk_Usage'] > MAX_DISK_PERCENT:
        alerts.append(f"CRITICAL: Disk Usage is high at {data['Disk_Usage']}%")
    
    if data['CPU_Usage'] > MAX_CPU_PERCENT:
        alerts.append(f"CRITICAL: CPU Usage is high at {data['CPU_Usage']}%")
    
    if data['Memory_Usage'] > MAX_MEM_PERCENT:
        alerts.append(f"CRITICAL: Memory Usage is high at {data['Memory_Usage']}%")
        
    for svc, status in data['services'].items():
       if status != 'active':
           alerts.append(f"WARNING: Service {svc} is {status}") 
    
    for eps, status in data['endpoints'].items():
        if status == "000":
            alerts.append(f"CRITICAL: Endpoint {eps} is UNREACHABLE (Timeout or DNS failure).")
        elif status.startswith("4"):
            alerts.append(f"WARNING: Endpoint {eps} is REACHABLE but returned Client Error {status}.")
        elif status.startswith("5"):
            alerts.append(f"WARNING: Endpoint {eps} is REACHABLE but returned Server Error {status}.")
        elif status != "200":
            alerts.append(f"WARNING: Endpoint {eps} returned unexpected HTTP code {status}.")    
    
    return alerts

#Execution block to check if the file is run directly by a human in a terminal, or whether it is being borrowed by another file
if __name__== "__main__":
    metrics = fetch_metrics()
    active_alerts = analyze_metrics(metrics)
    
    timestamp=datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    device=socket.gethostname()
    user=getpass.getuser()
    
    print("--- Infrastructure Report ---")
    
    with open(LOG_FILE, "a") as log:
        if len(active_alerts)==0:
            msg = "System is HEALTHY. No alerts."
            print(msg)
            log.write(f"[{timestamp}] [{device}] [{user}] - {msg}\n")
        else:
            for alert in active_alerts:
                print(alert)
                log.write(f"[{timestamp}] [{device}] [{user}] - {alert}\n")
        