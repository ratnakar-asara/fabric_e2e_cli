#!/bin/bash

printf "==================================================================\n\n"
echo " mmmmmm  mmmm         m    m               mmmmm               "
echo "     #\" \"   \"#        #    #  m mm         #   \"# m   m  m mm  "
echo "    m\"      m\"        #mmmm#  #\"  \"        #mmmm\" #   #  #\"  # "
echo "   m\"     m\"          #    #  #            #   \"m #   #  #   # "
echo "  m\"    m#mmmm        #    #  #            #    \" \"mm\"#  #   # "
printf "\n"
echo "  mmmm mmmmmmm   mm   mmmmm mmmmmmm mmmmmm mmmm  "
echo " #\"   \"   #      ##   #   \"#   #    #      #   \"m"
echo " \"#mmm    #     #  #  #mmmm\"   #    #mmmmm #    #"
echo "     \"#   #     #mm#  #   \"m   #    #      #    #"
echo " \"mmm#\"   #    #    # #    \"   #    #mmmmm #mmm\" "
printf "\n\n==================================================================\n\n"

CHAINCODE_NAME="mycc"
# This uses default channel 'testchainid'
ORDERER_IP=orderer0.example.com:7050
LOG_LEVEL="error"

START_COUNT=100
END_COUNT=1200
INTERVAL=100
SLEEP_TIME=3

CHANNEL_NAME="$1"
: ${CHANNEL_NAME:="mychannel"}
: ${TIMEOUT:="60"}
COUNTER=1
MAX_RETRY=5
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer0.example.com/msp/cacerts/ca.example.com-cert.pem

mkdir -p /opt/gopath/src/github.com/hyperledger/fabric/vendor/itpUtils && mv  ../examples/chaincode/go/auction/*api.go /opt/gopath/src/github.com/hyperledger/fabric/vendor/itpUtils/

echo "Channel name : "$CHANNEL_NAME

function wait(){
	printf "\nWait for $1 secs\n"
	sleep $1
}
function errMessage() {
                echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
		echo
		echo " mmmmmm   mm   mmmmm  m      m    m mmmmm  mmmmmm"
		echo " #        ##     #    #      #    # #   \"# #     "
		echo " #mmmmm  #  #    #    #      #    # #mmmm\" #mmmmm"
		echo " #       #mm#    #    #      #    # #   \"m #     "
		echo " #      #    # mm#mm  #mmmmm \"mmmm\" #    \" #mmmmm"
		cp -r /opt/gopath/src/github.com/hyperledger/fabric/vendor/itpUtils/* ../examples/chaincode/go/auction/
   		exit 1
}
function verifyResult () {
	if [ $1 -ne 0 ] ; then
		echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
		errMessage
	fi
}

function setGlobals () {

	if [ $1 -eq 0 -o $1 -eq 1 ] ; then
		CORE_PEER_LOCALMSPID="Org1MSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
		if [ $1 -eq 0 ]; then
			CORE_PEER_ADDRESS=peer0.org1.example.com:7051
		else
			CORE_PEER_ADDRESS=peer1.org1.example.com:7051
			CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
		fi
	else
		CORE_PEER_LOCALMSPID="Org2MSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
		if [ $1 -eq 2 ]; then
			CORE_PEER_ADDRESS=peer0.org2.example.com:7051
		else
			CORE_PEER_ADDRESS=peer1.org2.example.com:7051
		fi
	fi

	env |grep CORE
}

function createChannel() {
	setGlobals 0

        if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel create -o $ORDERER_IP -c $CHANNEL_NAME -f ./channel-artifacts/channel.tx >&log.txt
	else
		peer channel create -o $ORDERER_IP -c $CHANNEL_NAME -f ./channel-artifacts/channel.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Channel creation failed"
	echo "===================== Channel \"$CHANNEL_NAME\" is created successfully ===================== "
	echo
}

function updateAnchorPeers() {
        PEER=$1
        setGlobals $PEER

        if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel create -o $ORDERER_IP -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx >&log.txt
	else
		peer channel create -o $ORDERER_IP -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Anchor peer update failed"
	echo "===================== Anchor peers for org \"$CORE_PEER_LOCALMSPID\" on \"$CHANNEL_NAME\" is updated successfully ===================== "
	echo
}

## Sometimes Join takes time hence RETRY atleast for 5 times
function joinWithRetry () {
	peer channel join -b $CHANNEL_NAME.block  >&log.txt
	res=$?
	cat log.txt
	if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=` expr $COUNTER + 1`
		echo "PEER$1 failed to join the channel, Retry after 2 seconds"
		sleep 2
		joinWithRetry $1
	else
		COUNTER=1
	fi
        verifyResult $res "After $MAX_RETRY attempts, PEER$ch has failed to Join the Channel"
}

function joinChannel () {
	for ch in 0 1 2 3; do
		setGlobals $ch
		joinWithRetry $ch
		echo "===================== PEER$ch joined on the channel \"$CHANNEL_NAME\" ===================== "
		sleep 2
		echo
	done
}

function installChaincode () {
	for (( id=0; id<4; id++ ))
	do
		setGlobals $id
        	peer chaincode install -n $CHAINCODE_NAME -v 1.0 -p github.com/hyperledger/fabric/examples/chaincode/go/auction >&log.txt
		res=$?
		cat log.txt
       	 	verifyResult $res "Chaincode installation on remote peer PEER$id has Failed"
	done
	echo "===================== Chaincode is installed on all remote peers ===================== "
	echo
}

function instantiateChaincode () {
	PEER=$1
	setGlobals $PEER
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
                peer chaincode instantiate -o $ORDERER_IP -C $CHANNEL_NAME -n $CHAINCODE_NAME -v 1.0 -c '{"Args":["init"]}' -P "OR ('Org1MSP.member','Org2MSP.member')" >&log.txt
	else
                peer chaincode instantiate -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_NAME -v 1.0 -c '{"Args":["init"]}' -P "OR ('Org1MSP.member','Org2MSP.member')" >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Chaincode instantiation on PEER$PEER on channel '$CHANNEL_NAME' failed"
	echo "===================== Chaincode Instantiation on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
	echo
	wait 10
}
function downloadImages() {
	for (( id=0; id<4; id++ ))
	do
		setGlobals $id
		printf "\n-------- BEGIN DOWNLOAD IMAGES PEER$id --------\n"
		peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_NAME -c  '{"Args":["iDownloadImages", "DOWNLOAD"]}' --logging-level=$LOG_LEVEL
		printf "\n-------- END DOWNLOAD IMAGES PEER$id--------\n"
	done
}

function postUsers() {
	printf "\n-------- START POST USERS --------\n"
	setGlobals 0
	peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_NAME -c  '{"Args":["iPostUser","100", "USER", "Ashley Hart", "TRD",  "Morrisville Parkway, #216, Morrisville, NC 27560", "9198063535", "ashley@itpeople.com", "SUNTRUST", "0001732345", "0234678", "2017-01-02 15:04:05"]}' --logging-level=$LOG_LEVEL
	res=$?
	test $? -eq 0 && peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME  -n $CHAINCODE_NAME -c  '{"Args":["iPostUser","200", "USER", "Sotheby", "AH",  "One Picadally Circus , #216, London, UK ", "9198063535", "admin@sotheby.com", "Standard Chartered", "0001732345", "0234678", "2017-01-02 15:04:05"]}' --logging-level=$LOG_LEVEL
	test $? -eq 0 && peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME  -n $CHAINCODE_NAME -c  '{"Args":["iPostUser","300", "USER", "Barry Smith", "TRD",  "155 Regency Parkway, #111, Cary, 27518 ", "9198063535", "barry@us.ibm.com", "RBC Centura", "0001732345", "0234678", "2017-01-02 15:04:05"]}' --logging-level=$LOG_LEVEL
	res=$?
	setGlobals 1
	test $? -eq 0 && peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME  -n $CHAINCODE_NAME -c  '{"Args":["iPostUser","400", "USER", "Cindy Patterson", "TRD",  "155 Sunset Blvd, Beverly Hills, CA, USA ", "9058063535", "cpatterson@hotmail.com", "RBC Centura", "0001732345", "0234678", "2017-01-02 15:04:05"]}' --logging-level=$LOG_LEVEL
	test $? -eq 0 && peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME  -n $CHAINCODE_NAME -c  '{"Args":["iPostUser","500", "USER", "Tamara Haskins", "TRD",  "155 Sunset Blvd, Beverly Hills, CA, USA ", "9058063535", "tamara@yahoo.com", "RBC Centura", "0001732345", "0234678", "2017-01-02 15:04:05"]}' --logging-level=$LOG_LEVEL
	test $? -eq 0 && peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME  -n $CHAINCODE_NAME -c  '{"Args":["iPostUser","600", "USER", "NY Life", "INS",  "155 Broadway, New York, NY, USA ", "9058063535", "barry@nyl.com", "RBC Centura", "0001732345", "0234678", "2017-01-02 15:04:05"]}' --logging-level=$LOG_LEVEL
	res=$?
	setGlobals 2
	test $? -eq 0 && peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME  -n $CHAINCODE_NAME -c  '{"Args":["iPostUser","700", "USER", "J B Hunt", "SHP",  "One Johnny Blvd, Rogers, AR, USA ", "9058063535", "jess@jbhunt.com", "RBC Centura", "0001732345", "0234678", "2017-01-02 15:04:05"]}' --logging-level=$LOG_LEVEL
 	test $? -eq 0 && peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_NAME -c  '{"Args":["iPostUser","800", "USER", "R&R Trading", "AH",  "155 Sunset Blvd, Beverly Hills, CA, USA ", "9058063535", "larry@rr.com", "RBC Centura", "0001732345", "0234678", "2017-01-02 15:04:05"]}' --logging-level=$LOG_LEVEL
	test $? -eq 0 && peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME  -n $CHAINCODE_NAME -c  '{"Args":["iPostUser","900", "USER", "Gregory Huffman", "TRD",  "155 Sunset Blvd, Beverly Hills, CA, USA ", "9058063535", "tamara@yahoo.com", "RBC Centura", "0001732345", "0234678", "2017-01-02 15:04:05"]}' --logging-level=$LOG_LEVEL
	res=$?
	setGlobals 3
	test $? -eq 0 && peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME  -n $CHAINCODE_NAME -c  '{"Args":["iPostUser","1000", "USER", "Texas Life", "INS",  "155 Broadway, New York, NY, USA ", "9058063535", "barry@nyl.com", "RBC Centura", "0001732345", "0234678", "2017-01-02 15:04:05"]}' --logging-level=$LOG_LEVEL
	test $? -eq 0 && peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME  -n $CHAINCODE_NAME -c  '{"Args":["iPostUser","1100", "USER", "B J Hunt", "SHP",  "One Johnny Blvd, Rogers, AR, USA ", "9058063535", "jess@jbhunt.com", "RBC Centura", "0001732345", "0234678", "2017-01-02 15:04:05"]}' --logging-level=$LOG_LEVEL
 	test $? -eq 0 && peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_NAME -c  '{"Args":["iPostUser","1200", "USER", "R&S Trading", "AH",  "155 Sunset Blvd, Beverly Hills, CA, USA ", "9058063535", "larry@rr.com", "RBC Centura", "0001732345", "0234678", "2017-01-02 15:04:05"]}' --logging-level=$LOG_LEVEL

	verifyResult $? "POST User request execution on of the PEERs failed "

	echo "===================== POST USER trxns on one of the PEERs on the channel '$CHANNEL_NAME' is successful ===================== "
	wait $SLEEP_TIME
}

function getUsers() {
	printf "\n-------- START GET USERS --------\n"
        setGlobals $1
	for (( id=$START_COUNT; id<=$END_COUNT; id=$id+$INTERVAL ))
	do
		OUTPUT=$(peer chaincode query -C $CHANNEL_NAME -n $CHAINCODE_NAME -c "{\"Args\": [\"qGetUser\", \"$id\"]}")
		printf "\n########### Query Result for User $id: \n"
		echo $OUTPUT  | awk -F ': |\n' '{print $2}' | jq "."
	done
	printf "\n-------- END GET USERS --------\n"
}

function postItems() {
	printf "\n-------- START POST ITEMS --------\n"
        setGlobals $1
	OUTPUT=$(peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_NAME -c  '{"Args":["iPostItem", "100", "ARTINV", "Shadows by Asppen", "Asppen Messer", "20140202", "Original", "landscape", "Canvas", "15 x 15 in", "art1.png","600", "100", "2017-01-23 14:04:05"]}' --logging-level=$LOG_LEVEL)
	 OUTPUT=$(peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_NAME -c  '{"Args":["iPostItem", "200", "ARTINV", "modern Wall Painting", "Scott Palmer", "20140202", "Reprint", "landscape", "Acrylic", "10 x 10 in", "art2.png","2600", "300", "2017-01-23 14:04:05"]}' --logging-level=$LOG_LEVEL)
	 OUTPUT=$(peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_NAME -c  '{"Args":["iPostItem", "300", "ARTINV", "Splash of Color", "Jennifer Drew", "20160115", "Reprint", "modern", "Water Color", "15 x 15 in", "art3.png","1600", "100", "2017-01-23 14:04:05"]}' --logging-level=$LOG_LEVEL)
	 OUTPUT=$(peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_NAME -c  '{"Args":["iPostItem", "400", "ARTINV", "Female Water Color", "David Crest", "19900115", "Original", "modern", "Water Color", "12 x 17 in", "art4.png","9600", "100", "2017-01-23 14:04:05"]}' --logging-level=$LOG_LEVEL)
	 OUTPUT=$(peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_NAME -c  '{"Args":["iPostItem", "500", "ARTINV", "Nature", "James Thomas", "19900115", "Original", "modern", "Water Color", "12 x 17 in", "item-001.jpg","1800", "100", "2017-01-23 14:04:05"]}' --logging-level=$LOG_LEVEL)
	 OUTPUT=$(peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_NAME -c  '{"Args":["iPostItem", "600", "ARTINV", "Ladys Hair", "James Thomas", "19900115", "Original", "landscape", "Acrylic", "12 x 17 in", "item-002.jpg","1200", "300", "2017-01-23 14:04:05"]}' --logging-level=$LOG_LEVEL)
	 OUTPUT=$(peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_NAME -c  '{"Args":["iPostItem", "700", "ARTINV", "Flowers", "James Thomas", "19900115", "Original", "modern", "Acrylic", "12 x 17 in", "item-003.jpg","1000", "300", "2017-01-23 14:04:05"]}' --logging-level=$LOG_LEVEL)
	 OUTPUT=$(peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_NAME -c  '{"Args":["iPostItem", "800", "ARTINV", "Women at work", "James Thomas", "19900115", "Original", "modern", "Acrylic", "12 x 17 in", "item-004.jpg","1500", "400", "2017-01-23 14:04:05"]}' --logging-level=$LOG_LEVEL)
	 OUTPUT=$(peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_NAME -c  '{"Args":["iPostItem", "900", "ARTINV", "People", "James Thomas", "19900115", "Original", "modern", "Acrylic", "12 x 17 in", "people.gif","900", "400", "2017-01-23 14:04:05"]}' --logging-level=$LOG_LEVEL)
	OUTPUT=$(peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_NAME -c  '{"Args":["iPostItem", "1000", "ARTINV", "Shadows by Asppen", "Asppen Messer", "20140202", "Original", "landscape", "Canvas", "15 x 15 in", "art5.png","600", "1000", "2017-01-23 14:04:05"]}' --logging-level=$LOG_LEVEL)
	 OUTPUT=$(peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_NAME -c  '{"Args":["iPostItem", "1100", "ARTINV", "modern Wall Painting", "Scott Palmer", "20140202", "Reprint", "landscape", "Acrylic", "10 x 10 in", "art6.png","2600", "1100", "2017-01-23 14:04:05"]}' --logging-level=$LOG_LEVEL)
	 OUTPUT=$(peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_NAME -c  '{"Args":["iPostItem", "1200", "ARTINV", "Splash of Color", "Jennifer Drew", "20160115", "Reprint", "modern", "Water Color", "15 x 15 in", "art7.png","1600", "1200", "2017-01-23 14:04:05"]}' --logging-level=$LOG_LEVEL)
	wait $SLEEP_TIME
}

##TODO: Make a Generic query function for all
function getItems() {
	printf "\n-------- START GET ITEMS --------\n"
        setGlobals $1
	for (( id=$START_COUNT; id<=$END_COUNT; id=$id+$INTERVAL ))
	do
		OUTPUT=$(peer chaincode query -C $CHANNEL_NAME -n $CHAINCODE_NAME -c "{\"Args\": [\"qGetItem\", \"$id\"]}")
		printf "\n########### Query Result for Item $id: \n"
		AES_KEY=$(echo $OUTPUT  | awk -F ': |\n' '{print $2}' | jq ".AES_Key")
		echo $OUTPUT | awk -F ': |\n' '{print $2}' | jq "."
	done
	printf "\n-------- END GET ITEMS --------\n"
}
function postAuction() {
	printf "\n-------- START POST AUCTION --------\n"
        setGlobals $1
	peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_NAME -c '{"Args":["iPostAuctionRequest", "1111", "AUCREQ", "100", "200", "100", "04012016", "1200", "1800", "INIT", "2017-02-13 09:05:00","2017-02-13 09:05:00", "2017-02-13 09:10:00"]}' --logging-level=$LOG_LEVEL
	printf "\n-------- END POST AUCTION --------\n"
	wait $SLEEP_TIME
}

function openAuctionRequestForBids(){
	printf "\n-------- START OPEN AUCTION FOR BIDS--------\n"
        setGlobals $1
	peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME  -n $CHAINCODE_NAME  -c '{"Args":["iOpenAuctionForBids", "1111", "OPENAUC", "10", "2017-02-13 09:18:00"]}' --logging-level=$LOG_LEVEL
	printf "\n-------- END OPEN AUCTION FOR BIDS--------\n"
	wait $SLEEP_TIME
}

function submitBids() {
	printf "\n-------- START SUBMIT BIDS --------\n"
        setGlobals $1
	let index=1
	for (( id=$START_COUNT; id<=$END_COUNT; id=$id+$INTERVAL ))
	do
		[ $id -eq 200 ] && continue
		let price=$(shuf -i 1200-12000 -n 1)
		peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME  -n $CHAINCODE_NAME -c "{\"Args\":[\"iPostBid\", \"1111\", \"BID\", \"$index\", \"100\", \"$id\", \"$price\", \"2017-02-13 09:19:00\"]}" --logging-level=$LOG_LEVEL
		index=` expr $index + 1 `
	done
	printf "\n-------- END SUBMIT BIDS --------\n"
	wait $SLEEP_TIME
}

function closeAuction(){
	printf "\n-------- START CLOSE AUCTION --------\n"
        setGlobals $1
	peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME  -n $CHAINCODE_NAME -c '{"Args": ["iCloseOpenAuctions", "2016", "CLAUC", "2017-01-23 13:53:00.3 +0000 UTC"]}' --logging-level=$LOG_LEVEL &>logs.txt
	printf "\n-------- END CLOSE AUCTION --------\n"
	wait $SLEEP_TIME
	peer chaincode query -C $CHANNEL_NAME -n $CHAINCODE_NAME -c "{\"Args\": [\"qGetItem\", \"100\"]}" &>logs.txt
	printf "\n########### Query Result for Item 100: \n"
	OUTPUT=$(cat logs.txt | awk -F 'Result: | 2017' '{print $2}')
	USER_ID=$(echo $OUTPUT  | jq ".CurrentOwnerID")
	AES_KEY=$(echo $OUTPUT  | jq ".AES_Key")
	echo $OUTPUT | awk -F ': |\n' '{print $2}' | jq "."
	#echo $OUTPUT
	wait $SLEEP_TIME
}

function transferItem(){
        setGlobals $1
	printf "\n-------- START TRANSFER ITEM--------\n"
	printf "\n USER ID : $USER_ID"
	printf "\n AES KEY : $AES_KEY\n"

	OUTPUT=$(peer chaincode invoke -o $ORDERER_IP --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME  -n $CHAINCODE_NAME -c "{\"Args\": [\"iTransferItem\", \"100\", $USER_ID, $AES_KEY, \"800\", \"XFER\",\"2017-01-24 11:00:00\"]}" --logging-level=$LOG_LEVEL)
	printf "\n-------- END TRANSFER ITEM--------\n"
	wait $SLEEP_TIME
	printf "\n-------- Query Item 100 again --------\n"
	OUTPUT=$(peer chaincode query -C $CHANNEL_NAME  -n $CHAINCODE_NAME -c '{"Args": ["qGetItem", "100"]}')
	echo $OUTPUT | awk -F ': |\n' '{print $2}' | jq "."
	printf "\n Check Item 100 is transferred from $USER_ID to 800\n"
}

## Create channel
echo "Creating channel..."
createChannel

## Join all the peers to the channel
echo "Having all peers join the channel..."
joinChannel

## Set the anchor peers for each org in the channel
echo "Updating anchor peers for org1..."
updateAnchorPeers 0
echo "Updating anchor peers for org2..."
updateAnchorPeers 2

## Install chaincode on Peer0/Org1 and Peer2/Org2
echo "Installing chaincode on org1/peer0/peer1 and Org2/peer0/peer1..."
installChaincode

#Instantiate chaincode on Peer2/Org2
echo "Instantiating chaincode on org2/peer2..."
instantiateChaincode 2


## POST USERS on all peers
postUsers

## Download images on all peer containers
downloadImages


#Query on chaincode to get all Users on Peer0/Org1
echo "GetUSers on org1/peer0..."
getUsers 0

## POST ITEMS on all peer0
postItems 0

getItems 0

postAuction 0

openAuctionRequestForBids 0

submitBids 0

closeAuction 0

transferItem 0

# Revert the files to original location ## FIXME this looks ugly
cp -r /opt/gopath/src/github.com/hyperledger/fabric/vendor/itpUtils/* ../examples/chaincode/go/auction/

printf "\n\n"
echo "  mmmm  m    m   mmm    mmm  mmmmmm  mmmm   mmmm "
echo " #\"   \" #    # m\"   \" m\"   \" #      #\"   \" #\"   \""
echo " \"#mmm  #    # #      #      #mmmmm \"#mmm  \"#mmm "
echo "     \"# #    # #      #      #          \"#     \"#"
echo " \"mmm#\" \"mmmm\"  \"mmm\"  \"mmm\" #mmmmm \"mmm#\" \"mmm#\""
printf "\n"

echo
echo "===================== All GOOD, End-2-End execution completed ===================== "
echo
exit 0
