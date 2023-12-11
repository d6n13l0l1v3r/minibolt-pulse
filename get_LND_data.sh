#!/bin/bash
chain=$1
color_green=$2
color_red=$3
ln_git_version=$4

SWD=$(pwd)
echo -ne '\r### Loading LND data \r'

ln_dir="/data/lnd"


if [ "${chain}" = "test" ]; then
  macaroon_path="${ln_dir}/data/chain/bitcoin/testnet/readonly.macaroon"
else
  macaroon_path="${ln_dir}/data/chain/bitcoin/mainnet/readonly.macaroon"
fi
ln_running=$(systemctl is-active lnd 2>&1)
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
if [ -z "${ln_running##*up*}" ] ; then
  lncli="/usr/local/bin/lncli --macaroonpath=${macaroon_path} --tlscertpath=${ln_dir}/tls.cert"
  $lncli getinfo 2>&1 | grep "Please unlock" >/dev/null
  wallet_unlocked=$?
else
  wallet_unlocked=0
fi
printf "%0.s#" {1..40}
echo -ne '\r### Loading LND data \r'

if [ "$wallet_unlocked" -eq "0" ] ; then
  alias_color="${color_red}"
  ln_alias="Wallet Locked"
  ln_walletbalance="?"
  ln_channelbalance="?"
  ln_sync_chain="false"
  ln_sync_graph="false"
  ln_channels_online="?"
  ln_channels_total="?"
  ln_connect_addr=""
  ln_external=""
  ln_pendingopen="?"
  ln_pendingforce="?"
  ln_waitingclose="?"
  ln_pendinglocal="?"
  ln_sum_balance="?"
  if [ $lnd_running = "up" ]; then
    ln_connect_guidance="You must first unlock your wallet: lncli unlock"
  else
    ln_connect_guidance="The LND service is down. Start the service:  sudo systemctl start lnd"
  fi
else
  # Reduce number of calls to LND by doing once and caching
  lncli_channelbalance=$(${lncli} channelbalance)
  lncli_getinfo=$(${lncli} getinfo)
  lncli_listchannels=$(${lncli} listchannels)
  lncli_pendingchannels=$(${lncli} pendingchannels)
  lncli_walletbalance=$(${lncli} walletbalance)

  alias_color="${color_grey}"
  ln_alias="$(echo ${lncli_getinfo} | jq -r '.alias')" 2>/dev/null
  ln_walletbalance="$(echo ${lncli_walletbalance} | jq -r '.confirmed_balance')" 2>/dev/null
  ln_channelbalance="$(echo ${lncli_channelbalance} | jq -r '.balance')" 2>/dev/null

  ln_sync_chain="$(echo ${lncli_getinfo} | jq -r '.synced_to_chain')" 2>/dev/null
  ln_sync_graph="$(echo ${lncli_getinfo} | jq -r '.synced_to_graph')" 2>/dev/null

  printf "%0.s#" {1..46}

  echo -ne '\r### Loading LND data - connect info \r'

  ln_channels_online="$(echo ${lncli_getinfo} | jq -r '.num_active_channels')" 2>/dev/null
  ln_channels_total="$(echo ${lncli_listchannels} | jq '.[] | length')" 2>/dev/null
  ln_connect_addr="$(echo ${lncli_getinfo} | jq -r '.uris[0]')" 2>/dev/null
  ln_connect_guidance="lncli connect ${ln_connect_addr}"
  if [ -z "${ln_connect_addr##*onion*}" ]; then
    ln_external="Using TOR Address"
  else
    ln_external="Using Clearnet"
  fi

  printf "%0.s#" {1..52}
  echo -ne '\r### Loading LND data - pending channels \r'

  ln_pendingopen=$(echo ${lncli_pendingchannels} | jq '.pending_open_channels[].channel.local_balance|tonumber ' | awk '{sum+=$0} END{print sum}')
  if [ -z "${ln_pendingopen}" ]; then
    ln_pendingopen=0
  fi

  ln_pendingforce=$(echo ${lncli_pendingchannels} | jq '.pending_force_closing_channels[].channel.local_balance|tonumber ' | awk '{sum+=$0} END{print sum}')
  if [ -z "${ln_pendingforce}" ]; then
    ln_pendingforce=0
  fi

  ln_waitingclose=$(echo ${lncli_pendingchannels} | jq '.waiting_close_channels[].channel.local_balance|tonumber ' | awk '{sum+=$0} END{print sum}')
  if [ -z "${ln_waitingclose}" ]; then
    ln_waitingclose=0
  fi

  printf "%0.s#" {1..58}
  echo -ne '\r### Loading LND data - summary \r'

  ln_pendinglocal=$((ln_pendingopen + ln_pendingforce + ln_waitingclose))

  ln_sum_balance=0
  if [ -n "${ln_channelbalance}" ]; then
    ln_sum_balance=$((ln_channelbalance + ln_sum_balance ))
  fi
  if [ -n "${ln_walletbalance}" ]; then
    ln_sum_balance=$((ln_walletbalance + ln_sum_balance ))
  fi
  if [ -n "$ln_pendinglocal" ]; then
    ln_sum_balance=$((ln_sum_balance + ln_pendinglocal ))
  fi

  printf "%0.s#" {1..64}
  echo -ne '\r### Determining version \r'

  #create variable lnd version
  lndpi="$(echo ${lncli_getinfo} | jq -r '.version | split("=") | .[1]')" 2>/dev/null
  if [ "${lndpi}" = "${ln_git_version}" ]; then
    lnversion="${lndpi}"
    lnversion_color="${color_green}"
  else
    lnversion="${lndpi}"" Update!"
    lnversion_color="${color_red}"
  fi
fi


#create variables for ln_sync
if [ "${ln_sync_chain}" = "true" ]; then
  ln_sync_note1_color="${color_green}"
  ln_sync_note1="chain:OK"
else
  ln_sync_note1_color="${color_red}"
  ln_sync_note1="chain:No"
fi
if [ "${ln_sync_graph}" = "true" ]; then
  ln_sync_note2_color="${color_green}"
  ln_sync_note2="graph:OK"
else
  ln_sync_note2_color="${color_red}"
  ln_sync_note2="graph:No"
fi


printf "%0.s#" {1..70}
echo -ne '\r### Determining channel db size \r'

#get channel.db size
ln_channel_db_size=$(du -h ${ln_dir}/data/graph/mainnet/channel.db | awk '{print $1}')

printf "%0.s#" {1..76}
echo -ne '\r### Saving \r'

# Write to JSON file
ln_infofile="${SWD}/.minibolt.lnd.data.json"
ln_color=$(echo $lnd_color | sed 's/\\/\\\\/g')
lnversion_color=$(echo $lnversion_color | sed 's/\\/\\\\/g')
alias_color=$(echo $alias_color| sed 's/\\/\\\\/g')
ln_sync_note1_color=$(echo $ln_sync_note1_color | sed 's/\\/\\\\/g')
ln_sync_note2_color=$(echo $ln_sync_note2_color | sed 's/\\/\\\\/g')
printf '{"ln_running":"%s","ln_version":"%s","ln_version_available":"%s","ln_walletbalance":"%s","ln_channelbalance":"%s","ln_pendinglocal":"%s","ln_sum_balance":"%s","ln_channels_online":"%s","ln_channels_total":"%s","ln_channel_db_size":"%s","ln_color":"%s","ln_version_color":"%s","alias_color":"%s","ln_alias":"%s","ln_connect_guidance":"%s","ln_sync_note1":"%s","ln_sync_note1_color":"%s","ln_sync_note2":"%s","ln_sync_note2_color":"%s"}' "\
$ln_running" "$lnversion" "$ln_git_version" "$ln_walletbalance" "$ln_channelbalance" "$ln_pendinglocal" "$ln_sum_balance" "$ln_channels_online" "$ln_channels_total" "$ln_channel_db_size" "$lnd_color" "$lnversion_color" "$alias_color" "$ln_alias" "$ln_connect_guidance" "$ln_sync_note1" "$ln_sync_note1_color" "$ln_sync_note2" "$ln_sync_note2_color" > $ln_infofile
