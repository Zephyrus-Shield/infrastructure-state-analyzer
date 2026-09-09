#!/usr/bin/env bash

#error handling enforcement
set -euo pipefail

#Dynamically fetching the file paths
SCRIPT_DIR=$(dirname "$(realpath "$0")")

#Defining the path to the config file 
CONFIG_FILE="$SCRIPT_DIR/services.conf"

#Defining the path to the endpoints file
ENDPOINTS_FILE="$SCRIPT_DIR/endpoints.conf"

#function to gather memory usage
get_memory_usage(){
    local mem_percent
    mem_percent=$(free -m | awk 'NR==2 {printf "%.2f", ($3/$2) * 100}')
    echo "$mem_percent"
}

#get_memory_usage

#function to gather swap usage
get_swap_usage(){
    local swap_percent
    #swap is NR==3
    #If total swap ($2) is 0 then we should avoid division by zero and return 0.00% usage
    swap_percent=$(free -m | awk 'NR==3 {if ($2>0) printf "%.2f", ($3/$2) * 100; else print "0.00"}')
    echo "$swap_percent"
}

#function to gather root disk usage
get_disk_usage(){
    local disk_percent
    disk_percent=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
    echo "$disk_percent"
}

#function to gather cpu usage
get_cpu_usage(){
    local cpu_percent
    cpu_percent=$(vmstat 1 2 | tail -1 | awk '{print 100 - $15}')
    echo "$cpu_percent"
}


#function to gather service status data
get_service_status(){
    local service_name="$1"
    local status
    status=$(systemctl is-active --quiet "$service_name" && echo "active" || echo "inactive")
    echo "$status"
}

#function to check endpoints connectivity
get_endpoints_status(){
    local endpoint="$1"
    #just output the 3-digit HTTP code. No text
    curl -s -L -o /dev/null --connect-timeout 2 -w "%{http_code}" "$endpoint" || true
}

#calling the hardware metrics functions and saving their outputs to variables
mem=$(get_memory_usage)
swap=$(get_swap_usage)
disk=$(get_disk_usage)
cpu=$(get_cpu_usage)

#Build the services JSON string
services_json=""
while read -r svc; do
    current_status=$(get_service_status "$svc")
    #append each service and status to the string with a comma
    services_json+="\"$svc\": \"$current_status\", "
done < "$CONFIG_FILE"

#strip the trailing comma and space to make it a valid JSON
services_json=${services_json%, }

#Build the endpoints JSON string
endpoints_json=""
while read -r eps; do
    current_status=$(get_endpoints_status "$eps")
    #append each service and status to the string with a comma
    endpoints_json+="\"$eps\": \"$current_status\", "
done < "$ENDPOINTS_FILE"

#strip the trailing comma and space to make it a valid JSON string
endpoints_json=${endpoints_json%, }

#output the final JSON format
cat << EOF
{
"Memory_Usage": $mem,
"Swap_Usage": $swap,
"Disk_Usage": $disk,
"CPU_Usage": $cpu,
"services": {$services_json},
"endpoints": {$endpoints_json}
}
EOF

