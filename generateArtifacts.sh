#!/bin/bash +x

#set -e

: ${CHANNEL_NAME:="mychannel"}
CHANNEL_NAME=$1
echo $CHANNEL_NAME

export FABRIC_ROOT=$PWD/../..
export FABRIC_CFG_PATH=$PWD
echo

## Using docker-compose template replace private key file names with constants
function replacePrivateKey () {
	ARCH=`uname -s | grep Darwin`
	if [ "$ARCH" == "Darwin" ]; then
		OPTS="-it"
	else
		OPTS="-i"
	fi

	cp docker-compose-template.yaml docker-compose.yaml

        CURRENT_DIR=$PWD
        cd crypto-config/peerOrganizations/org1.example.com/ca/
        PRIV_KEY=$(ls *_sk)
        cd $CURRENT_DIR
        sed $OPTS "s/CA1_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose.yaml
        cd crypto-config/peerOrganizations/org2.example.com/ca/
        PRIV_KEY=$(ls *_sk)
        cd $CURRENT_DIR
        sed $OPTS "s/CA2_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose.yaml
}

## Generates Org certs using cryptogen tool
function generateCerts (){
	CRYPTOGEN=`which cryptogen || /bin/true`

	if [ "$CRYPTOGEN" == "" ]; then
	    echo "Building cryptogen"
	    make -C $FABRIC_ROOT cryptogen
	    CRYPTOGEN=$FABRIC_ROOT/build/bin/cryptogen
	else
            echo "Using cryptogen -> $CRYPTOGEN"
	fi

	echo
	echo "##########################################################"
	echo "##### Generate certificates using cryptogen tool #########"
	echo "##########################################################"
	$CRYPTOGEN generate --config=./crypto-config.yaml
	echo
}

## Generate orderer genesis block , channel configuration transaction and anchor peer update transactions
function generateChannelArtifacts() {

	CONFIGTXGEN=`which configtxgen || /bin/true`

	if [ "$CONFIGTXGEN" == "" ]; then
	    echo "Building configtxgen"
	    make -C $FABRIC_ROOT configtxgen
	    CONFIGTXGEN=$FABRIC_ROOT/build/bin/configtxgen
	else
            echo "Using configtxgen -> $CONFIGTXGEN"
	fi

	echo "##########################################################"
	echo "#########  Generating Orderer Genesis block ##############"
	echo "##########################################################"
	$CONFIGTXGEN -profile TwoOrgsOrdererGenesis -outputBlock ./channel-artifacts/orderer.block

	echo
	echo "#################################################################"
	echo "### Generating channel configuration transaction 'channel.tx' ###"
	echo "#################################################################"
	$CONFIGTXGEN -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/channel.tx -channelID $CHANNEL_NAME

	echo
	echo "#################################################################"
	echo "#######    Generating anchor peer update for Org0MSP   ##########"
	echo "#################################################################"
	$CONFIGTXGEN -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org0MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org0MSP

	echo
	echo "#################################################################"
	echo "#######    Generating anchor peer update for Org1MSP   ##########"
	echo "#################################################################"
	$CONFIGTXGEN -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org1MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org1MSP
	echo
}

generateCerts
replacePrivateKey
generateChannelArtifacts

