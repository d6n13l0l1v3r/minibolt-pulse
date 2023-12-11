#!/bin/bash
chain=$1
color_green=$2
color_red=$3
ln_git_version=$4

SWD=$(pwd)
echo -ne '\r### Loading CLN data \r'

ln_running=$(systemctl is-active lightningd 2>&1)
ln_color="${color_green}"
if [ -z "${ln_running##*inactive*}" ]; then
  ln_running="down"
  ln_color="${color_red}\e[7m"
else
  if [ -z "${ln_running##*failed*}" ]; then
    ln_running="down"
    ln_color="${color_red}\e[7m"
  else
    ln_running="up"
  fi
fi

lncli="/home/lightningd/lightning/cli/lightning-cli"

printf "%0.s#" {1..63}
echo -ne '\r### Loading CoreLN data \r'


alias_color="${color_grey}"
ln_alias="$(${lncli} getinfo | jq -r '.alias')" 2>/dev/null

# Reduce number of calls to CLN by doing once and caching
lncli_getinfo=$(${lncli} getinfo 2>&1)
lncli_listfunds=$(${lncli} listfunds 2>&1)

ln_walletbalance=0
#check if len(outputs) == 0 --> empty wallet
#amount_of_wallet_transactions=$(echo ${lncli_listfunds} | jq -r '.outputs | length')
#if [ $amount_of_wallet_transactions -gt 0 ];then
#ln_walletbalance=$(echo ${lncli_listfunds} | jq -r '.outputs[0].amount_msat| tonumber')
#fi

amount_of_wallet_transactions=$(echo ${lncli_listfunds} | jq -r '.outputs | length')
index=0

while [ $index -lt $amount_of_wallet_transactions ]; do
    # Access the amount_msat for the current transaction
    current_amount_msat=$(echo ${lncli_listfunds} | jq -r ".outputs[$index].amount_msat | tonumber")

    # Add the current amount to ln_walletbalance
    ln_walletbalance=$((ln_walletbalance + current_amount_msat))

    # Increment the index for the next iteration
    index=$((index + 1))
done

## Show channel balance
ln_channelbalance=0
##check if len(channels) == 0 --> no channels
#amount_of_channels=$(echo ${lncli_listfunds} | jq -r '.channels | length')
#if [ $amount_of_channels -gt 0 ];then
#ln_channelbalance=$(echo ${lncli_listfunds} | jq -r '[.channels[].our_amount_msat] | add')
#fi

amount_of_channels=$(echo ${lncli_listfunds} | jq -r '.channels | length')
index=0

while [ $index -lt $amount_of_channels ]; do
    # Access the state for the current channel
    current_channel_state=$(echo ${lncli_listfunds} | jq -r ".channels[$index].state")

    # Check if the state is not "ONCHAIN"
    if [ "$current_channel_state" != "ONCHAIN" ]; then
        # Access the our_amount_msat for the current channel
        current_channel_amount_msat=$(echo ${lncli_listfunds} | jq -r ".channels[$index].our_amount_msat | tonumber")

        # Add the current channel amount to ln_channelbalance
        ln_channelbalance=$((ln_channelbalance + current_channel_amount_msat))
    fi

    # Increment the index for the next iteration
    index=$((index + 1))
done

printf "%0.s#" {1..70}

ln_pendinglocal=0

ln_sum_balance=0
#convert balance from millisats to sats
if [ -n "${ln_channelbalance}" ]; then
  ln_channelbalance=$((ln_channelbalance / 1000))
  ln_sum_balance=$((ln_channelbalance + ln_sum_balance))
fi
if [ -n "${ln_walletbalance}" ]; then
  ln_walletbalance=$((ln_walletbalance / 1000))
  ln_sum_balance=$((ln_walletbalance + ln_sum_balance))
fi
if [ -n "${ln_pendinglocal}" ]; then
  ln_pendinglocal=$((ln_pendinglocal / 1000))
  ln_sum_balance=$((ln_sum_balance + ln_pendinglocal))
fi


#create variable ln_version
lnpi=$(echo ${lncli_getinfo} | jq -r '.version') 2>/dev/null
if [ "${lnpi}" = "${ln_git_version}" ]; then
  ln_version="${lnpi}"
  ln_version_color="${color_green}"
else
  ln_version="${lnpi}"" Update!"
  ln_version_color="${color_red}"
fi

#create variables for ln_sync
ln_sync_warning_bitcoind=$(echo ${lncli_getinfo} | jq -r '.warning_bitcoind_sync') 2>/dev/null
ln_sync_warning_lightningd=$(echo ${lncli_getinfo} | jq -r '.warning_lightningd_sync') 2>/dev/null
ln_sync_note2_color="${color_red}"
ln_sync_note2=""
if [ "${ln_sync_warning_bitcoind}" = "null" ]; then
  if [ "${ln_sync_warning_lightningd}" = "null" ]; then
    ln_sync_note1_color="${color_green}"
    ln_sync_note1="chain:OK"
  else
    ln_sync_note1_color="${color_red}"
    ln_sync_note1="chain:No"
  fi
else
  ln_sync_note1_color="${color_red}"
  ln_sync_note1="chain:No"
fi

#get channel.db size
ln_dir="/data/lightningd"
ln_channel_db_size=$(du -h ${ln_dir}/bitcoin/lightningd.sqlite3 | awk '{print $1}')

# Write to JSON file
ln_infofile="${SWD}/.minibolt.cln.data.json"
ln_color=$(echo $ln_color | sed 's/\\/\\\\/g')
ln_version_color=$(echo $ln_version_color | sed 's/\\/\\\\/g')
alias_color=$(echo $alias_color| sed 's/\\/\\\\/g')
ln_sync_note1_color=$(echo $ln_sync_note1_color | sed 's/\\/\\\\/g')
ln_sync_note2_color=$(echo $ln_sync_note2_color | sed 's/\\/\\\\/g')
printf '{"ln_running":"%s","ln_version":"%s","ln_walletbalance":"%s","ln_channelbalance":"%s","ln_pendinglocal":"%s","ln_sum_balance":"%s","ln_channels_online":"%s","ln_channels_total":"%s","ln_channel_db_size":"%s","ln_color":"%s","ln_version_color":"%s","alias_color":"%s","ln_alias":"%s","ln_connect_guidance":"%s","ln_sync_note1":"%s","ln_sync_note1_color":"%s","ln_sync_note2":"%s","ln_sync_note2_color":"%s"}' "\
$ln_running" "$ln_version" "$ln_walletbalance" "$ln_channelbalance" "$ln_pendinglocal" "$ln_sum_balance" "$ln_channels_online" "$ln_channels_total" "$ln_channel_db_size" "$ln_color" "$ln_version_color" "$alias_color" "$ln_alias" "$ln_connect_guidance" "$ln_sync_note1" "$ln_sync_note1_color" "$ln_sync_note2" "$ln_sync_note2_color" > $ln_infofile
