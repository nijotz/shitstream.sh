LOCKFILE="shit.lock"
MP3DIR="mp3s"
mkdir -p ${MP3DIR}/in

# For now just echo, will add verbosity options later
function v {
    echo $*
}
