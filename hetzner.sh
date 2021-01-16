#!/bin/sh

# DEPS:
# jq, curl
# ENV:
# __IP: IPv4 or IPv6 address to set
# password: Hetzner Auth Token
# domain: domain record to update.

local __API_URL __ZONE __SUBDOMAIN __TTL __TYPE __ID __RESULT_CODE __PAYLOAD

__API_URL=https://dns.hetzner.com/api/v1
__ZONE=${domain#*.}
__SUBDOMAIN=${domain%%.*}
__TTL=60
if [ "$use_ipv6" -ne 0 ]; then
	__TYPE="AAAA"
else
	__TYPE="A"
fi

__ZONE_ID=$(curl -s -L -H Auth-API-Token": $password" \
		$__API_URL/zones/$__ZONE | \
	jq -re '.zone.id')
if [ $? -ne 0 ] || [ "x$__ZONE_ID" = "x" ]; then
	write_log 14 "Error: Cannot find zone '$__ZONE'"
	exit 1
fi

__ID=$(curl -s -L -H Auth-API-Token": $password" \
		$__API_URL/records\?zone_id\=$__ZONE_ID | \
	jq -re ".records[] | select(.type==\"$TYPE\" and .name == \"home\") | .id")
__RESULT_CODE=$?

__PAYLOAD="{
	\"value\": \"$__IP\",
	\"ttl\": $__TTL,
	\"type\": \"$__TYPE\",
	\"name\": \"$__SUBDOMAIN\",
	\"zone_id\": \"$__ZONE_ID\"
}"

if [ $(echo "$__ID" | wc -l) -eq 1 ] && [ "$__RESULT_CODE" -eq 0 ]; then
	write_log 7 "Info: Record found. Updating..."
	curl -s -L -X "PUT" -H Auth-API-Token": $password" \
		-d "$__PAYLOAD" \
		"$__API_URL/records/$__ID" > /dev/null

	write_log 7 "DDNS Provider answered:\n$(cat $DATFILE)"
elif [ "x$__ID" = "x" ]; then
	write_log 7 "Info: No Record yet. Create a new one..."

	curl -s -L -X "POST" -H Auth-API-Token": $password" \
		-d "$__PAYLOAD" \
		$__API_URL/records > /dev/null

	write_log 7 "DDNS Provider answered:\n$(cat $DATFILE)"
else
	write_log 14 "ERROR: Multiple entries. This is wrong"
fi
