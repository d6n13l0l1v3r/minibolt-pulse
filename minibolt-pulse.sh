#!/bin/bash
# /etc/systemd/system/Minibolt-pulse.sh
set -u

# make executable and copy script to /etc/update-motd.d/
# user must be able to execute bitcoin-cli and lncli

# Script configuration
# ------------------------------------------------------------------------------

# set datadir
bitcoin_dir="/data/bitcoin"
# determine second drive info
drivecount=$(lsblk --output MOUNTPOINT | grep / | grep -v /boot | sort | wc -l)
if [ $drivecount -gt 1 ]; then
  ext_storage2nd=$(lsblk --output MOUNTPOINT | grep / | grep -v /boot | sort | sed -n 2p)
else
  ext_storage2nd=""
fi
SWD=$(pwd)

# expected service names... common alternate values supported
sn_bitcoin="bitcoind"
sn_lnd="lnd"
sn_cln="lightningd"                     # cln, lightningd
sn_btcrpcexplorer="btcrpcexplorer"
sn_electrs="electrs"
sn_fulcrum="fulcrum"
sn_rtl="rtl"                            # rtl, ridethelightning
sn_thunderhub="thunderhub"
sn_teos="teos"
sn_specter="specterd"
sn_mempool="mempool"
sn_lnbits="lnbits"
sn_sparrow="sparrow"

# Helper functionality
# ------------------------------------------------------------------------------

# set colors
color_red='\033[0;31m'
color_green='\033[0;32m'
color_blue='\033[0;34m'
color_yellow='\033[0;33m'
color_grey='\033[0;37m'
color_orange='\033[38;5;208m'
color_magenta='\033[0;35m'
color_white='\033[37;3m'
# git repo urls latest version
bitcoin_git_repo_url="https://api.github.com/repos/bitcoin/bitcoin/releases/latest"
electrs_git_repo_url="https://api.github.com/repos/romanz/electrs/releases/latest"
btcrpcexplorer_git_repo_url="https://api.github.com/repos/janoside/btc-rpc-explorer/releases/latest"
rtl_git_repo_url="https://api.github.com/repos/Ride-The-Lightning/RTL/releases/latest"
fulcrum_git_repo_url="https://api.github.com/repos/cculianu/Fulcrum/releases/latest"
thunderhub_git_repo_url="https://api.github.com/repos/apotdevin/thunderhub/releases/latest"
lnd_git_repo_url="https://api.github.com/repos/lightningnetwork/lnd/releases/latest"
cln_git_repo_url="https://api.github.com/repos/ElementsProject/lightning/releases/latest"
teos_git_repo_url="https://api.github.com/repos/talaia-labs/rust-teos/releases/latest"
lnbits_git_repo_url=" https://api.github.com/repos/lnbits/lnbits/releases/latest"
specter_git_repo_url="https://api.github.com/repos/cryptoadvance/specter-desktop/releases/latest"
mempool_git_repo_url=" https://api.github.com/repos/mempool/mempool/releases/latest"
sparrow_git_repo_url="https://api.github.com/repos/sparrowwallet/sparrow/releases/latest"


# controlled abort on Ctrl-C
trap_ctrlC() {
  echo -e "\r"
  printf "%0.s " {1..80}
  printf "\n"
  exit
}

trap trap_ctrlC SIGINT SIGTERM

# print usage information for script
usage() {
  echo "Minibolt Welcome: system status overview
usage: $(basename "$0")
--help             display this help and exit
--last-update, -l  show when files with saved values were last updated
--mock, -m         run the script mocking the Lightning data

This script can be run on startup: make it executable and
copy the script to /etc/update-motd.d/
"
}


function secs_since_modified() {
  filename="$1"
  mtime=$(stat -c %Y "$filename")
  now=$(date +%s)
  elapsed=$((now - mtime))

  echo $elapsed
}

function convert_secs_to_hhmmss() {
  seconds=$1
  hours=$((seconds / 3600))
  minutes=$((seconds % 3600 / 60))
  seconds=$((seconds % 60))
  formatted=$(printf "%02d:%02d:%02d\n" $hours $minutes $seconds)

  echo "$formatted"
}

function convert_secs_to_min() {
  seconds=$1
  minutes=$((seconds / 60))

  echo $minutes
}
function print_last_modified() {
  path=$1
  seconds=$(secs_since_modified "$path")
  echo "${path}: modified $(convert_secs_to_hhmmss ${seconds}) ago [$(convert_secs_to_min ${seconds}) mins]"
}

updatesstatusfile="${SWD}/.minibolt.updates.json"
gitstatusfile="${SWD}/.minibolt.versions.json"
lnd_infofile="${SWD}/.minibolt.lnd.data.json"
cln_infofile="${SWD}/.minibolt.cln.data.json"

function last_updated() {
  print_last_modified $updatesstatusfile
  print_last_modified $gitstatusfile
  print_last_modified $lnd_infofile
  print_last_modified $cln_infofile
}



# check script arguments
mockmode=0
if [[ ${#} -gt 0 ]]; then
  if [[ "${1}" == "-m" ]] || [[ "${1}" == "--mock" ]]; then
    mockmode=1
      elif [[ "${1}" == "-l" ]] || [[ "${1}" == "--last-update" ]]; then
    last_updated
    exit 0
  else
    usage
    exit 0
  fi
fi


# Print first welcome message
# ------------------------------------------------------------------------------
printf "
${color_yellow}Minibolt %s:${color_grey} Sovereign \033[38;5;208m"₿"\033[0;37mitcoin full node
${color_yellow}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
" "v2"
# Get system updates
# ------------------------------------------------------------------------------


save_updates() {
  # write to json file
  cat >${updatesstatusfile} <<EOF
{
  "updates": {
    "available": "${updates}"
  }
}
EOF
}

load_updates() {
  updates=$(cat ${updatesstatusfile} | jq -r '.updates.available')
}

fetch_updates() {
  # get available update
  updates="$((`apt list --upgradable 2>/dev/null | wc -l`-1))"
}

# Check if we should check for new updates (limit to once every 6 hours)
checkupdate="0"
if [ ! -f "$updatesstatusfile" ]; then
  checkupdate="1"
else
  checkupdate=$(find "${updatesstatusfile}" -mmin +360 | wc -l)
fi

# Fetch or load
if [ "${checkupdate}" -eq "1" ]; then
  fetch_updates
  # write to json file
  save_updates
else
  # load from file
  load_updates
fi

if [ ${updates} -gt 0 ]; then
  color_updates="${color_red}"
  updates="${updates} [run 'upgrade']"
else
  color_updates="${color_green}"
fi





# Gather system data
# ------------------------------------------------------------------------------
printf "%0.s#" {1..40}
echo -ne '\r### Loading System data \r'

# get uptime & load
load=$(w|head -1|sed -E 's/.*load average: (.*)/\1/')
uptime=$(w|head -1|sed -E 's/.*up (.*),.*user.*/\1/'|sed -E 's/([0-9]* days).*/\1/')

# get highest reported temperature
temp="N/A"
color_temp="${color_grey}"
hitemp=$(grep . /sys/class/hwmon/*/* /sys/class/thermal/*/* 2>/dev/null | grep "temp" | grep "input" | awk '{split($0,a,":"); print a[2]}' | sort -r | head -n 1)
if (( hitemp > 0 )); then
  temp=$((hitemp/1000))
  if [ ${temp} -gt 68 ]; then
    color_temp="${color_red}"
  elif [ ${temp} -gt 55 ]; then
    color_temp="${color_yellow}"
  else
    color_temp="${color_green}"
  fi
  temp="${temp}""°C"
fi

# get memory
ram_avail=$(free --mebi | grep Mem | awk '{ print $7 }')

if [ "${ram_avail}" -lt 100 ]; then
  color_ram="${color_red}"
else
  color_ram=${color_green}
fi

# get storage
storage_free_ratio=$(printf "%.0f" "$(df | grep "/$" | awk '{ print $4/$2*100 }')") 2>/dev/null
storage=$(printf "%s" "$(df -h|grep '/$'|awk '{print $4}')") 2>/dev/null

if [ "${storage_free_ratio}" -lt 10 ]; then
  color_storage="${color_red}"
else
  color_storage=${color_green}
fi

storage2nd_free_ratio=$(printf "%.0f" "$(df  | grep ${ext_storage2nd} | awk '{ print $4/$2*100 }')") 2>/dev/null
storage2nd=$(printf "%s" "$(df -h|grep ${ext_storage2nd}|awk '{print $4}')") 2>/dev/null

if [ -z "${storage2nd}" ]; then
  storage2nd="none"
  color_storage2nd=${color_grey}
else
  storage2nd="${storage2nd} free"
  if [ "${storage2nd_free_ratio}" -lt 10 ]; then
    color_storage2nd="${color_red}"
  else
    color_storage2nd=${color_green}
  fi
fi

# get network traffic (sums from all devices but excludes the loopback named 'lo')
network_rx=$(ip -j -s link show | jq '.[] | [(select(.ifname!="lo") | .stats64.rx.bytes)//0] | add' | awk -v OFMT='%.0f' '{sum+=$0} END{print sum}' | numfmt --to=iec)
network_tx=$(ip -j -s link show | jq '.[] | [(select(.ifname!="lo") | .stats64.tx.bytes)//0] | add' | awk -v OFMT='%.0f' '{sum+=$0} END{print sum}' | numfmt --to=iec)

# Gather application versions
# ------------------------------------------------------------------------------


save_minibolt_versions() {
  # write to json file
  cat >${gitstatusfile} <<EOF
{
  "githubversions": {
    "bitcoin": "${btcgit}",
    "lnd": "${lndgit}",
    "cln": "${clngit}",
    "electrs": "${electrsgit}",
    "blockexplorer": "${btcrpcexplorergit}",
    "rtl": "${rtlgit}",
    "fulcrum": "${fulcrumgit}",
    "thunderhub": "${thunderhubgit}",
    "lnbits": "${lnbitsgit}",
    "mempool": "${mempoolgit}",
    "specter": "${spectergit}",
    "teos": "${teosgit}",
    "sparrow": "${sparrowgit}"
  }
}
EOF
}

load_minibolt_versions() {
  btcgit=$(cat ${gitstatusfile} | jq -r '.githubversions.bitcoin')
  lndgit=$(cat ${gitstatusfile} | jq -r '.githubversions.lnd')
  clngit=$(cat ${gitstatusfile} | jq -r '.githubversions.cln')
  electrsgit=$(cat ${gitstatusfile} | jq -r '.githubversions.electrs')
  btcrpcexplorergit=$(cat ${gitstatusfile} | jq -r '.githubversions.blockexplorer')
  rtlgit=$(cat ${gitstatusfile} | jq -r '.githubversions.rtl')
  fulcrumgit=$(cat ${gitstatusfile} | jq -r '.githubversions.fulcrum')
  thunderhubgit=$(cat ${gitstatusfile} | jq -r '.githubversions.thunderhub')
  mempoolgit=$(cat ${gitstatusfile} | jq -r '.githubversions.mempool')
  lnbitsgit=$(cat ${gitstatusfile} | jq -r '.githubversions.lnbits')
  spectergit=$(cat ${gitstatusfile} | jq -r '.githubversions.specter')
  teosgit=$(cat ${gitstatusfile} | jq -r '.githubversions.teos')
  sparrowgit=$(cat ${gitstatusfile} | jq -r '.githubversions.sparrow')
}

fetch_githubversion_bitcoin() {
  btcgit=$(curl -s --connect-timeout 5 ${bitcoin_git_repo_url} | jq -r '.tag_name | select(.!=null)')
}
fetch_githubversion_lightning() {
  ln_git_version=$(curl -s --connect-timeout 5 $ln_git_repo_url | jq -r '.tag_name | select(.!=null)')
}
fetch_githubversion_electrs() {
  electrsgit=$(curl -s --connect-timeout 5 ${electrs_git_repo_url} | jq -r '.tag_name | select(.!=null)')
}
fetch_githubversion_btcrpcexplorer() {
  btcrpcexplorergit=$(curl -s --connect-timeout 5 ${btcrpcexplorer_git_repo_url} | jq -r '.tag_name | select(.!=null)')
}
fetch_githubversion_rtl() {
  rtlgit=$(curl -s --connect-timeout 5 ${rtl_git_repo_url} | jq -r '.tag_name | select(.!=null)')
}
fetch_githubversion_fulcrum() {
  fulcrumgit=$(curl -s --connect-timeout 5 ${fulcrum_git_repo_url} | jq -r '.tag_name | select(.!=null)')
}
fetch_githubversion_thunderhub() {
  thunderhubgit=$(curl -s --connect-timeout 5 ${thunderhub_git_repo_url} | jq -r '.tag_name | select(.!=null)')
}
fetch_githubversion_lnd() {
  lndgit=$(curl -s --connect-timeout 5 ${lnd_git_repo_url} | jq -r '.tag_name | select(.!=null)')
}
fetch_githubversion_cln() {
  clngit=$(curl -s --connect-timeout 5 ${cln_git_repo_url} | jq -r '.tag_name | select(.!=null)')
}
fetch_githubversion_teos() {
  teosgit=$(curl -s --connect-timeout 5 ${teos_git_repo_url} | jq -r '.tag_name | select(.!=null)')
}
fetch_githubversion_lnbits() {
  lnbitsgit=$(curl -s --connect-timeout 5 ${lnbits_git_repo_url} | jq -r '.tag_name | select(.!=null)')
}
fetch_githubversion_specter() {
  spectergit=$(curl -s --connect-timeout 5 ${specter_git_repo_url} | jq -r '.tag_name | select(.!=null)')
}
fetch_githubversion_mempool() {
  mempoolgit=$(curl -s --connect-timeout 5 ${mempool_git_repo_url} | jq -r '.tag_name | select(.!=null)')
}
fetch_githubversion_sparrow() {
  sparrowgit=$(curl -s --connect-timeout 5 ${sparrow_git_repo_url} | jq -r '.tag_name | select(.!=null)')
}


# Check if we should update with latest versions from github (limit to once every 6 hours)
gitupdate="0"
if [ ! -f "$gitstatusfile" ]; then
  gitupdate="1"
else
  gitupdate=$(find "${gitstatusfile}" -mmin +360 | wc -l)
fi

# Fetch or load
if [ "${gitupdate}" -eq "1" ]; then
  # Calls to github
  fetch_githubversion_bitcoin
  fetch_githubversion_lnd
  fetch_githubversion_cln
  fetch_githubversion_electrs
  fetch_githubversion_btcrpcexplorer
  fetch_githubversion_rtl
  fetch_githubversion_fulcrum
  fetch_githubversion_thunderhub
  fetch_githubversion_teos
  fetch_githubversion_lnbits
  fetch_githubversion_specter
  fetch_githubversion_mempool
  fetch_githubversion_sparrow
  # write to json file
  save_minibolt_versions
else
  # load from file
  load_minibolt_versions
fi

# Sanity check values
resaveminibolt="0"
if [ -z "$btcgit" ]; then
  fetch_githubversion_bitcoin
  resaveminibolt="1"
fi
if [ -z "$lndgit" ]; then
  fetch_githubversion_lnd
  resaveminibolt="1"
fi
if [ -z "$clngit" ]; then
  fetch_githubversion_cln
  resaveminibolt="1"
fi
if [ -z "$electrsgit" ]; then
  fetch_githubversion_electrs
  resaveminibolt="1"
fi
if [ -z "$btcrpcexplorergit" ]; then
  fetch_githubversion_btcrpcexplorer
  resaveminibolt="1"
fi
if [ -z "$rtlgit" ]; then
  fetch_githubversion_rtl
  resaveminibolt="1"
fi
if [ -z "$fulcrumgit" ]; then
  fetch_githubversion_fulcrum
  resaveminibolt="1"
fi
if [ -z "$thunderhubgit" ]; then
  fetch_githubversion_thunderhub
  resaveminibolt="1"
fi
if [ -z "$lnbitsgit" ]; then
  fetch_githubversion_lnbits
  resaveminibolt="1"
fi
if [ -z "$spectergit" ]; then
  fetch_githubversion_specter
  resaveminibolt="1"
fi
if [ -z "$teosgit" ]; then
  fetch_githubversion_teos
  resaveminibolt="1"
fi
if [ -z "$mempoolgit" ]; then
  fetch_githubversion_mempool
  resaveminibolt="1"
fi
if [ -z "$sparrowgit" ]; then
  fetch_githubversion_sparrow
  resaveminibolt="1"
fi
if [ "${resaveminibolt}" -eq "1" ]; then
  save_minibolt_versions
fi



# Gather Bitcoin Core data
# ------------------------------------------------------------------------------
printf "%0.s#" {1..50}
echo -ne '\r### Loading Bitcoin Core data \r'

bitcoind_running=$(systemctl is-active ${sn_bitcoin} 2>&1)
bitcoind_color="${color_green}"
if [ -z "${bitcoind_running##*inactive*}" ]; then
  bitcoind_running="down"
  bitcoind_color="${color_red}"
else
  bitcoind_running="up"
fi
btc_path=$(command -v bitcoin-cli)
if [ -n "${btc_path}" ]; then

  # Reduce number of calls to bitcoin by doing once and caching
  bitcoincli_getblockchaininfo=$(bitcoin-cli -datadir=${bitcoin_dir} getblockchaininfo 2>&1)
  bitcoincli_getmempoolinfo=$(bitcoin-cli -datadir=${bitcoin_dir} getmempoolinfo 2>&1)
  bitcoincli_getnetworkinfo=$(bitcoin-cli -datadir=${bitcoin_dir} getnetworkinfo 2>&1)
  bitcoincli_getpeerinfo=$(bitcoin-cli -datadir=${bitcoin_dir} getpeerinfo 2>&1)

  chain="$(echo ${bitcoincli_getblockchaininfo} | jq -r '.chain')"
  btc_title="itcoin"
  btc_title="${btc_title} (${chain}net)"

  # create variable btcversion
  btcpi=$(bitcoin-cli -version |sed -n 's/^.*version //p')
  case "${btcpi}" in
    *"${btcgit}"*)
      btcversion="$btcpi"
      btcversion_color="${color_green}"
      ;;
    *)
      btcversion="$btcpi"" Update!"
      btcversion_color="${color_red}"
      ;;
  esac

  # get sync status
  block_chain="$(echo ${bitcoincli_getblockchaininfo} | jq -r '.headers')"
  block_verified="$(echo ${bitcoincli_getblockchaininfo} | jq -r '.blocks')"
  if [ -n "${block_chain}" ]; then
    block_diff=$(("${block_chain}" - "${block_verified}"))
  else
    block_diff=999999
  fi

  progress="$(echo ${bitcoincli_getblockchaininfo} | jq -r '.verificationprogress')"
  sync_percentage=$(printf "%.2f%%" "$(echo "${progress}" | awk '{print 100 * $1}')")

  if [ "${block_diff}" -eq 0 ]; then      # fully synced
    sync="OK"
    sync_color="${color_green}"
    sync_behind="[#${block_chain}]"
  elif [ "${block_diff}" -eq 1 ]; then    # fully synced
    sync="OK"
    sync_color="${color_green}"
    sync_behind="-1 block"
  elif [ "${block_diff}" -le 10 ]; then   # <= 10 blocks behind
    sync="Behind"
    sync_color="${color_red}"
    sync_behind="-${block_diff} blocks"
  else
    sync="In progress"
    sync_color="${color_red}"
    sync_behind="${sync_percentage}"
  fi

  # get mem pool transactions
  mempool=$(echo ${bitcoincli_getmempoolinfo} | jq -r '.size')

  # get connection info
  connections=$(echo ${bitcoincli_getnetworkinfo} | jq -r '.connections')
  inbound=$(echo ${bitcoincli_getpeerinfo} | jq '.[] | select(.inbound == true)' | jq -s 'length')
  outbound=$(echo ${bitcoincli_getpeerinfo} | jq '.[] | select(.inbound == false)' | jq -s 'length')

  # create variable btcversion
  btcpi=$(bitcoin-cli -version |sed -n 's/^.*version //p')
  case "${btcpi}" in
    *"${btcgit}"*)
      btcversion="$btcpi"
      btcversion_color="${color_green}"
      ;;
    *)
      btcversion="$btcpi"" Update!"
      btcversion_color="${color_red}"
      ;;
  esac
else
  # bitcoin-cli was not found
  btc_title="Bitcoin not active"
  btcversion="Is Bitcoin installed?"
  btcversion_color="${color_red}"
  connections="0"
  inbound="0"
  mempool="0"
  outbound="0"
  sync="Not synching"
  sync_color="${color_red}"
  sync_behind=""
fi

# Gather LN data based on preferred implementation
# ------------------------------------------------------------------------------
printf "%0.s#" {1..60}

load_lightning_data() {

  ln_file_content=$(cat $cln_infofile)
  ln_color="$(echo $ln_file_content | jq -r '.ln_color')"
  ln_version_color="$(echo $ln_file_content | jq -r '.ln_version_color')"
  alias_color="$(echo $ln_file_content | jq -r '.alias_color')"
  ln_running="$(echo $ln_file_content | jq -r '.ln_running')"
  ln_version="$(echo $ln_file_content | jq -r '.ln_version')"
  ln_walletbalance="$(echo $ln_file_content | jq -r '.ln_walletbalance')"
  ln_channelbalance="$(echo $ln_file_content | jq -r '.ln_channelbalance')"
  ln_pendinglocal="$(echo $ln_file_content | jq -r '.ln_pendinglocal')"
  ln_sum_balance="$(echo $ln_file_content | jq -r '.ln_sum_balance')"
  ln_channels_online="$(echo $ln_file_content | jq -r '.ln_channels_online')"
  ln_channels_total="$(echo $ln_file_content | jq -r '.ln_channels_total')"
  ln_channel_db_size="$(echo $ln_file_content | jq -r '.ln_channel_db_size')"
  ln_connect_guidance="$(echo $ln_file_content | jq -r '.ln_connect_guidance')"
  ln_alias="$(echo $ln_file_content | jq -r '.ln_alias')"
  ln_sync_note1="$(echo $ln_file_content | jq -r '.ln_sync_note1')"
  ln_sync_note1_color="$(echo $ln_file_content | jq -r '.ln_sync_note1_color')"
  ln_sync_note2="$(echo $ln_file_content | jq -r '.ln_sync_note2')"
  ln_sync_note2_color="$(echo $ln_file_content | jq -r '.ln_sync_note2_color')"
}

# Prepare Lightning output data (name, version, data lines)
# ------------------------------------------------------------------------------
echo -ne '\r### Loading Lightning data \r'
lserver_found=0
lserver_label="No Lightning Server"
lserver_running=""
lserver_color="${color_red}"
lserver_version=""
lserver_version_color="${color_red}"
lserver_dataline_1="${color_grey}"
lserver_dataline_2="${color_grey}"
lserver_dataline_3="${color_grey}"
lserver_dataline_4="${color_grey}"
lserver_dataline_5="${color_grey}"
lserver_dataline_6="${color_grey}"
lserver_dataline_7="${color_grey}"
ln_footer=""
lnd_status=$(systemctl is-enabled $sn_lnd 2>&1)
cln_status=$(systemctl is-enabled $sn_cln 2>&1)
if [ "$cln_status" != "enabled" ]; then # fallback from lightningd to cln for service name
  sn_cln="cln"
  cln_status=$(systemctl is-enabled $sn_cln 2>&1)
fi
# Mock specific
if [ "${mockmode}" -eq 1 ]; then
  ln_alias="MyMiniBolt v2"
  ln_walletbalance="100000"
  ln_channelbalance="200000"
  ln_pendinglocal="50000"
  ln_sum_balance="350000"
  ln_channels_online="34"
  ln_channels_total="36"
  ln_channel_db_size="615M"
  ln_connect_guidance="lncli connect cdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcd \n
  					[AT] version3onionaddressgobbLedegookLookingL3ttersandnumbers.onion:9735"
  lserver_label="Lightning (MOCK)"
  lserver_running="up"
  lserver_color="${color_green}"
  lserver_version="v0.6.15"
  lserver_version_color="${color_green}"
  alias_color="${color_magenta}"
  ln_footer=$(printf "For others to connect to this lightning node: ${alias_color}${ln_alias}${color_grey}\n${ln_connect_guidance}")
  # data lines
  lserver_dataline_1=$(printf "${color_grey}Sync%10s" "ready")
  lserver_dataline_2=$(printf "${color_orange}"₿"${color_grey}%18s sat" "${ln_walletbalance}")
  lserver_dataline_3=$(printf "${color_grey}%3s %16s sat" "⚡" "${ln_channelbalance}")
  lserver_dataline_4=$(printf "${color_grey}%3s %16s sat" "∑" "${ln_sum_balance}")
  lserver_dataline_5=$(printf "${color_grey}%s/%s channels" "${ln_channels_online}" "${ln_channels_total}")
  lserver_dataline_6=$(printf "${color_grey}Channel.db size: ${color_green}%s" "${ln_channel_db_size}")
# LND specific
elif [ "$lnd_status" = "enabled" ]; then
  lnd_status=$(systemctl is-active $sn_lnd 2>&1)
  lserver_found=1
  lserver_label="Lightning (LND)"
  lserver_running="down"
  if [ "$lnd_status" = "active" ]; then
    lserver_running="up"
    lserver_color="${color_green}"
    # version specific stuff
    "$(dirname "$0")/get_LND_data.sh" $chain $color_green $color_red $lndgit
    load_lightning_data
    lserver_version="$(echo $ln_file_content | jq -r '.ln_version')"
    lserver_version_color="$(echo $ln_file_content | jq -r '.ln_version_color')"
    ln_footer=$(printf "For others to connect to this lightning node: ${alias_color}${ln_alias}${color_grey}\n${ln_connect_guidance}")
    # data lines
    lserver_dataline_1=$(printf "${color_grey}Sync${ln_sync_note1_color}%10s${ln_sync_note2_color}%9s" "${ln_sync_note1}" "${ln_sync_note2}")
    lserver_dataline_2=$(printf "${color_orange}"₿"${color_grey}%18s sat" "${ln_walletbalance}")
    lserver_dataline_3=$(printf "${color_grey}%3s %16s sat" "⚡" "${ln_channelbalance}")
    lserver_dataline_4=$(printf "${color_grey}%3s %16s sat" "⏳" "${ln_pendinglocal}")
    lserver_dataline_5=$(printf "${color_grey}%3s %17s sat" "∑" "${ln_sum_balance}")
    lserver_dataline_6=$(printf "${color_grey}%s/%s channels" "${ln_channels_online}" "${ln_channels_total}")
    lserver_dataline_7=$(printf "${color_grey}Channel.db size: ${color_green}%s" "${ln_channel_db_size}")
  fi
# Core Lightning specific
elif [ "$cln_status" = "enabled" ];  then
  cln_status=$(systemctl is-active $sn_cln 2>&1)
  lserver_found=1
  lserver_label="Lightning (CLN)"
  lserver_running="down"
  if [ "$cln_status" = "active" ]; then
    lserver_running="up"
    lserver_color="${color_green}"
    # version specific stuff
    "$(dirname "$0")/get_CLN_data.sh" $chain $color_green $color_red $clngit
    load_lightning_data
    lserver_version="$(echo $ln_file_content | jq -r '.ln_version')"
    lserver_version_color="$(echo $ln_file_content | jq -r '.ln_version_color')"
    ln_footer=$(printf "For others to connect to this lightning node: ${alias_color}${ln_alias}${color_grey}\n${ln_connect_guidance}")
    # data lines
    lserver_dataline_1=$(printf "${color_grey}Sync${ln_sync_note1_color}%10s${ln_sync_note2_color}%9s" "${ln_sync_note1}" "${ln_sync_note2}")
    lserver_dataline_2=$(printf "${color_orange}"₿"${color_grey}%18s sat" "${ln_walletbalance}")
    lserver_dataline_3=$(printf "${color_grey}%3s %16s sat" "⚡" "${ln_channelbalance}")
    lserver_dataline_4=$(printf "${color_grey}%3s %17s sat" "∑" "${ln_sum_balance}")
    lserver_dataline_5=$(printf "${color_grey}%s/%s channels" "${ln_channels_online}" "${ln_channels_total}")
    lserver_dataline_6=$(printf "${color_grey}Lightning DB size: ${color_green}%s" "${ln_channel_db_size}")
  fi
# ... add any future supported lightning server implementation checks here
fi
if [ "$lserver_found" -eq 0 ]; then
  lserver_color="${color_grey}"
fi



# Gather Electrs or Fulcrum data
# ------------------------------------------------------------------------------
printf "%0.s#" {1..65}
echo -ne '\r### Loading Electrum Server data \r'
eserver_found=0
eserver_label="No Electrum Server"
eserver_running=""
eserver_color="${color_red}"
eserver_version=""
eserver_version_color="${color_red}"
electrs_status=$(systemctl is-enabled ${sn_electrs} 2>&1)
fulcrum_status=$(systemctl is-enabled ${sn_fulcrum} 2>&1)
# Electrs specific
if [ "$electrs_status" = "enabled" ]; then
  electrs_status=$(systemctl is-active ${sn_electrs} 2>&1)
  eserver_found=1
  eserver_label="Electrs"
  eserver_running="down"
  if [ "$electrs_status" = "active" ]; then
    eserver_running="up"
    eserver_color="${color_green}"
    # Request params are client_name, protocol_version. Example result being parsed: ["Electrs 0.9.10", "1.4"]
    electrspi=$(echo '{"jsonrpc": "2.0", "method": "server.version", "params": [ "minibolt", "1.4" ], "id": 0}' | netcat 127.0.0.1 50001 -q 1 | jq -r '.result[0]' | awk '{print "v"substr($1,9)}')
    if [ "$electrspi" = "$electrsgit" ]; then
      eserver_version="$electrspi"
      eserver_version_color="${color_green}"
    else
      eserver_version="$electrspi"" Update!"
    fi
  fi
# Fulcrum specific
elif [ "$fulcrum_status" = "enabled" ];  then
  fulcrum_status=$(systemctl is-active ${sn_fulcrum} 2>&1)
  eserver_found=1
  eserver_label="Fulcrum"
  eserver_running="down"
  if [ "$fulcrum_status" = "active" ]; then
    eserver_running="up"
    eserver_color="${color_green}"
    fulcrumpi=$(Fulcrum --version | grep Fulcrum | awk '{print "v"$2}')
    if [ "$fulcrumpi" = "$fulcrumgit" ]; then
      eserver_version="$fulcrumpi"
      eserver_version_color="${color_green}"
    else
      eserver_version="$fulcrumpi"" Update!"
    fi
  fi
# ... add any future supported electrum server implementation checks here
fi
if [ "$eserver_found" -eq 0 ]; then
  eserver_color="${color_grey}"
fi

# Gather Mempool service data
# ------------------------------------------------------------------------------
printf "%0.s#" {1..70}
echo -ne '\r### Loading mempool service  data \r'
mserver_found=0
mserver_label="No mempool service"
mserver_running=""
mserver_color="${color_red}"
mserver_version=""
mserver_version_color="${color_red}"
mempool_status=$(systemctl is-enabled ${sn_mempool} 2>&1)
# mempool service specific
if [ "$mempool_status" = "enabled" ]; then
  un_mempool=$(systemctl show -pUser ${sn_mempool} | awk '{split($0,a,"="); print a[2]}')
  mempool_status=$(systemctl is-active ${sn_mempool} 2>&1)
  mserver_found=1
  mserver_label="Mempool"
  mserver_running="down"
  if [ "$mempool_status" = "active" ]; then
    mserver_running="up"
    mserver_color="${color_green}"
    mempoolpi=v$(cat /home/${un_mempool}/mempool/backend/dist/api/version.json| jq -r '.version')
    if [ "$mempoolpi" = "$mempoolgit" ]; then
      mserver_version="$mempoolpi"
      mserver_version_color="${color_green}"
    else
      mserver_version="$mempoolpi"" Update!"
    fi
  fi
# ... add any future supported blockchain explorer implementation checks here
fi
if [ "$mserver_found" -eq 0 ]; then
  mserver_color="${color_grey}"
fi

# Gather TEOS service data
# ------------------------------------------------------------------------------
printf "%0.s#" {1..70}
echo -ne '\r### Loading TEOS service  data \r'
tserver_found=0
tserver_label="No teos service"
tserver_running=""
tserver_color="${color_red}"
tserver_version=""
tserver_version_color="${color_red}"
teos_status=$(systemctl is-enabled ${sn_teos} 2>&1)
teos_footer=""
# mempool service specific
if [ "$teos_status" = "enabled" ]; then
  un_teos=$(systemctl show -pUser ${sn_teos} | awk '{split($0,a,"="); print a[2]}')
  teos_status=$(systemctl is-active ${sn_teos} 2>&1)
  tserver_found=1
  tserver_label="TEOS"
  tserver_running="down"
  if [ "$teos_status" = "active" ]; then
    tserver_running="up"
    tserver_color="${color_green}"
    teospi=v$(teos-cli -V  |sed -n 's/^.*teos-cli //p')
    if [ "$teospi" = "$teosgit" ]; then
      tserver_version="$teospi"
      tserver_version_color="${color_green}"
    else
      tserver_version="$teospi"" Update!"
    fi
    #tower_connect_addr=$(teos-cli gettowerinfo | jq -r '.tower_id + "@" + .addresses[1].address + ":" + (.addresses[1].port | tostring)')
    tower_connect_addr=$(teos-cli gettowerinfo | jq -r '.tower_id')
    teos_connect_guidance="lightning-cli registertower ${tower_connect_addr}"
    teos_footer=$(printf "For others to connect to this Tower node: ${color_grey}\n${teos_connect_guidance}")
  fi
# ... add any future supported blockchain explorer implementation checks here
fi
if [ "$tserver_found" -eq 0 ]; then
  tserver_color="${color_grey}"
fi

# Gather Lnbits service data
# ------------------------------------------------------------------------------
printf "%0.s#" {1..70}
echo -ne '\r### Loading Lnbits service  data \r'
lbserver_found=0
lbserver_label="No Lnbits service"
lbserver_running=""
lbserver_color="${color_red}"
lbserver_version=""
lbserver_version_color="${color_red}"
lnbits_status=$(systemctl is-enabled ${sn_teos} 2>&1)
# mempool service specific
if [ "$lnbits_status" = "enabled" ]; then
  un_lnbits=$(systemctl show -pUser ${sn_lnbits} | awk '{split($0,a,"="); print a[2]}')
  lnbits_status=$(systemctl is-active ${sn_lnbits} 2>&1)
  lbserver_found=1
  lbserver_label="Lnbits"
  lbserver_running="down"
  if [ "$lnbits_status" = "active" ]; then
    lbserver_running="up"
    lbserver_color="${color_green}"
    lnbitspi=$(cat /home/${un_lnbits}/lnbits/pyproject.toml | grep '^version = "[^"]*"' | cut -d'"' -f2)
    if [ "$lnbitspi" = "$lnbitsgit" ]; then
      lbserver_version="$lnbitspi"
      lbserver_version_color="${color_green}"
    else
      lbserver_version="$lnbitspi"" Update!"
    fi
  fi
# ... add any future supported blockchain explorer implementation checks here
fi
if [ "$lbserver_found" -eq 0 ]; then
  lbserver_color="${color_grey}"
fi

# Gather specterd service data
# ------------------------------------------------------------------------------
printf "%0.s#" {1..70}
echo -ne '\r### Loading specterd service  data \r'
sdserver_found=0
sdserver_label="No specterd service"
sdserver_running=""
sdserver_color="${color_red}"
sdserver_version=""
sdserver_version_color="${color_red}"
specter_status=$(systemctl is-enabled ${sn_specter} 2>&1)
# mempool service specific
if [ "$specter_status" = "enabled" ]; then
  un_specter=$(systemctl show -pUser ${sn_specter} | awk '{split($0,a,"="); print a[2]}')
  specter_status=$(systemctl is-active ${sn_specter} 2>&1)
  sdserver_found=1
  sdserver_label="Specterd"
  sdserver_running="down"
  if [ "$specter_status" = "active" ]; then
    sdserver_running="up"
    sdserver_color="${color_green}"
    specterpi=$(cat /home/${un_specter}/.specter/migration_data.json | jq .events[].version | cut -d'"' -f2)
    if [ "$specterpi" = "$spectergit" ]; then
      sdserver_version="$specterpi"
      sdserver_version_color="${color_green}"
    else
      sdserver_version="$specterpi"" Update!"
    fi
  fi
# ... add any future supported blockchain explorer implementation checks here
fi
if [ "$sdserver_found" -eq 0 ]; then
  sdserver_color="${color_grey}"
fi

# Gather Bitcoin Explorer data
# ------------------------------------------------------------------------------
printf "%0.s#" {1..70}
echo -ne '\r### Loading Block Explorer data \r'
bserver_found=0
bserver_label="No Block Explorer"
bserver_running=""
bserver_color="${color_red}"
bserver_version=""
bserver_version_color="${color_red}"
btcrpcexplorer_status=$(systemctl is-enabled ${sn_btcrpcexplorer} 2>&1)
# BTC RPC Explorer specific
if [ "$btcrpcexplorer_status" = "enabled" ]; then
  un_btcrpcexplorer=$(systemctl show -pUser ${sn_btcrpcexplorer} | awk '{split($0,a,"="); print a[2]}')
  btcrpcexplorer_status=$(systemctl is-active ${sn_btcrpcexplorer} 2>&1)
  bserver_found=1
  bserver_label="Bitcoin Explorer"
  bserver_running="down"
  if [ "$btcrpcexplorer_status" = "active" ]; then
    bserver_running="up"
    bserver_color="${color_green}"
    btcrpcexplorerpi=v$(cd /home/${un_btcrpcexplorer}/btc-rpc-explorer; npm version | grep -oP "'btc-rpc-explorer': '\K(.*)(?=')")
    if [ "$btcrpcexplorerpi" = "$btcrpcexplorergit" ]; then
      bserver_version="$btcrpcexplorerpi"
      bserver_version_color="${color_green}"
    else
      bserver_version="$btcrpcexplorerpi"" Update!"
    fi
  fi
# ... add any future supported blockchain explorer implementation checks here
fi
if [ "$bserver_found" -eq 0 ]; then
  bserver_color="${color_grey}"
fi

# Gather Lightning Web App data
# ------------------------------------------------------------------------------
printf "%0.s#" {1..75}
echo -ne '\r### Loading Lightning Web App \r'

lwserver_found=0
lwserver_label="No Lightning Web App"
lwserver_running=""
lwserver_color="${color_red}"
lwserver_version=""
lwserver_version_color="${color_red}"
rtl_status=$(systemctl is-enabled ${sn_rtl} 2>&1)
if [ "$rtl_status" != "enabled" ]; then  # fallback from rtl to ridethelightning for service name
  sn_rtl="ridethelightning"
  rtl_status=$(systemctl is-enabled ${sn_rtl} 2>&1)
fi
thunderhub_status=$(systemctl is-enabled ${sn_thunderhub} 2>&1)
# Ride the Ligthning specific
if [ "$rtl_status" = "enabled" ]; then
  un_rtl=$(systemctl show -pUser ${sn_rtl} | awk '{split($0,a,"="); print a[2]}')
  rtl_status=$(systemctl is-active ${sn_rtl} 2>&1)
  lwserver_found=1
  lwserver_label="RTL"
  lwserver_running="down"
  if [ "$rtl_status" = "active" ]; then
    lwserver_running="up"
    lwserver_color="${color_green}"
    rtlpi=v$(cd /home/${un_rtl}/RTL; npm version | grep -oP "rtl: '\K(.*)(?=-beta')")
    if [ "$rtlpi" = "$rtlgit" ]; then
      lwserver_version="$rtlpi"
      lwserver_version_color="${color_green}"
    else
      lwserver_version="$rtlpi"" Update!"
    fi
  fi
# Thunderhub specific
elif [ "$thunderhub_status" = "enabled" ]; then
  un_thunderhub=$(systemctl show -pUser ${sn_thunderhub} | awk '{split($0,a,"="); print a[2]}')
  thunderhub_status=$(systemctl is-active ${sn_thunderhub} 2>&1)
  lwserver_found=1
  lwserver_label="Thunderhub"
  lwserver_running="down"
  if [ "$thunderhub_status" = "active" ]; then
    lwserver_running="up"
    lwserver_color="${color_green}"
    thunderhubpi=v$(cd /home/${un_thunderhub}/thunderhub; npm version | grep -oP "thunderhub: '\K(.*)(?=-beta')")
    if [ "$thunderhubpi" = "$thunderhubgit" ]; then
      lwserver_version="$thunderhubpi"
      lwserver_version_color="${color_green}"
    else
      lwserver_version="$thunderhubpi"" Update!"
    fi
  fi
# ... add any future supported lightning web app implementation checks here
fi
if [ "$lwserver_found" -eq 0 ]; then
  lwserver_color="${color_grey}"
fi

# Gather sparrow service data
# ------------------------------------------------------------------------------
printf "%0.s#" {1..70}
echo -ne '\r### Loading sparrow terminal  data \r'
spserver_found=0
spserver_label="Sparrow terminal"
spserver_running=""
spserver_color="${color_red}"
spserver_version=""
spserver_version_color="${color_red}"
# sparror terminal specific
spserver_color="${color_green}"
sparrowpi=$(Sparrow -v | awk '{print substr($0, index($0,$NF)+0)}')
if [ "$sparrowpi" = "$sparrowgit" ]; then
    spserver_version="$sparrowpi"
    spserver_version_color="${color_green}"
else
    spserver_version="$sparrowpi"" Update!"
fi

if [ "$spserver_found" -eq 0 ]; then
  spserver_color="${color_grey}"
fi


# Render output MiniBolt
# ------------------------------------------------------------------------------
echo -ne "\033[2K"
printf "${color_grey}cpu temp: ${color_temp}%-4s${color_grey}  tx: %-10s storage:   ${color_storage}%-11s ${color_grey}  load: %s${color_grey}
${color_grey}up: %-10s  rx: %-10s 2nd drive: ${color_storage2nd}%-11s${color_grey}   available mem: ${color_ram}%sM${color_grey}
${color_grey}System updates avalible: ${color_updates}%-21s${color_grey}
${color_yellow}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${color_grey}
${color_green}                          ${color_orange}"₿"${color_yellow}%-19s${bitcoind_color}%-4s${color_grey}   ${color_yellow}%-20s${lserver_color}%-4s${color_grey}
${color_green}                          ${btcversion_color}%-26s ${lserver_version_color}%-24s${color_grey}
${color_red}            ${color_grey}°${color_grey}             ${color_grey}Sync    ${sync_color}%-18s ${lserver_dataline_1}${color_grey}
${color_red}          ${color_grey}／/${color_grey}             ${color_grey}Mempool %-18s ${lserver_dataline_2}${color_grey}
${color_red}        ${color_grey}／ /${color_yellow}_____${color_yellow}         ${color_grey}Peers  %-22s  ${lserver_dataline_3}${color_grey}
${color_red}      ${color_grey}／_____ ${color_yellow} ／${color_yellow}                                    ${lserver_dataline_4}${color_grey}
${color_red}           ${color_yellow}/ ／${color_yellow}           ${color_yellow}%-20s${eserver_color}%-4s${color_grey}   ${lserver_dataline_5}${color_grey}
${color_red}          ${color_yellow}/／${color_yellow}             ${eserver_version_color}%-26s ${lserver_dataline_6}${color_grey}
${color_red}          ${color_yellow}°${color_yellow}                                          ${lserver_dataline_7}${color_grey}

${color_red} ${color_yellow}%-18s${color_grey}${bserver_color}%-6s${color_grey} ${color_yellow}%-18s${lwserver_color}%-8s${color_grey} ${color_yellow}%-18s${color_grey}${mserver_color}%-8s${color_grey}
${color_red} ${bserver_version_color}%-24s${color_grey} ${lwserver_version_color}%-24s${color_grey}   ${mserver_version_color}%-24s${color_grey}

${color_red} ${color_yellow}%-18s${color_grey}${tserver_color}%-6s${color_grey} ${color_yellow}%-18s${lbserver_color}%-8s${color_grey} ${color_yellow}%-18s${color_grey}${sdserver_color}%-8s${color_grey}
${color_red} ${tserver_version_color}%-24s${color_grey} ${lbserver_version_color}%-24s${color_grey}   ${sdserver_version_color}%-24s${color_grey}

${color_red} ${color_yellow}%-18s${color_grey}${spserver_color}
${color_red} ${spserver_version_color}%-24s${color_grey}

${color_grey}%s

${color_grey}%s

" \
"${temp}" "${network_tx}" "${storage} free" "${load}" \
"${uptime}" "${network_rx}" "${storage2nd}" "${ram_avail}" \
"${updates}" \
"${btc_title}" "${bitcoind_running}" "${lserver_label}" "${lserver_running}" \
"${btcversion}" "${lserver_version}" \
"${sync} ${sync_behind}" \
"${mempool} tx" \
"${connections} (📥${inbound} /📤${outbound})"  \
"${eserver_label}" "${eserver_running}" \
"${eserver_version}" \
"${bserver_label}" "${bserver_running}"  "${lwserver_label}" "${lwserver_running}" "${mserver_label}" "${mserver_running}" \
"${bserver_version}" "${lwserver_version}" "${mserver_version}" \
"${tserver_label}" "${tserver_running}"  "${lbserver_label}" "${lbserver_running}" "${sdserver_label}" "${sdserver_running}" \
"${tserver_version}" "v${lbserver_version}" "${sdserver_version}" \
"${spserver_label}" \
"v${spserver_version}" \
"${ln_footer}" \
"${teos_footer}"
