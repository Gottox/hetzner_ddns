#!/bin/sh

# ENV:
# __IP: IPv4 or IPv6 address to set
# password: Hetzner Auth Token
# domain: domain record to update.

API_URL=https://dns.hetzner.com/api/v1
TOKEN=${password}
ZONE=${domain#*.}
SUBDOMAIN=${domain%%.*}
TTL=60
if [ "$use_ipv6" -ne 0 ]; then
	TYPE="AAAA"
else
	TYPE="A"
fi

zone_id=$(curl -s -L -H Auth-API-Token": $TOKEN" \
		$API_URL/zones/$ZONE | \
	jq -re '.zone.id')
if [ $? -ne 0 ] || [ "$zone_id" == "" ]; then
	echo "Error: Cannot find zone $ZONE" >&2
	exit 1
fi

id=$(curl -s -L -H Auth-API-Token": $TOKEN" \
		$API_URL/records\?zone_id\=$zone_id | \
	jq -re ".records[] | select(.type==\"$TYPE\" and .name == \"home\") | .id")
result_code=$?

payload="{
	\"value\": \"$__IP\",
	\"ttl\": $TTL,
	\"type\": \"$TYPE\",
	\"name\": \"$SUBDOMAIN\",
	\"zone_id\": \"$zone_id\"
}"
if [ $(echo "$id" | wc -l) -eq 1 ] && [ "$result_code" -eq 0 ]; then
	echo "Info: Record found. Updating..." >&2
	exec curl -s -L -X "PUT" -H Auth-API-Token": $TOKEN" \
		-d "$payload" \
		"$API_URL/records/$id" > /dev/null
elif [ $(echo "$id" | wc -l) -eq 0 ]; then
	echo "Info: No Record yet. Create a new one..." >&2

	exec curl -s -L -X "POST" -H Auth-API-Token": $TOKEN" \
		-d "$payload" \
		$API_URL/records > /dev/null
else
	echo "ERROR: Multiple entries. This is wrong" >&2
	exit 1
fi
