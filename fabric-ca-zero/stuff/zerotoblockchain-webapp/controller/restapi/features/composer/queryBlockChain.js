/*
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

var path = require('path');
var fs = require('fs');
const express = require('express');
const app = express();
const cfenv = require('cfenv');
const appEnv = cfenv.getAppEnv();
app.set('port', appEnv.port);

const hfc = require('fabric-client');
//const hfcEH = require('fabric-client/lib/EventHub');

const svc = require('./Z2B_Services');
const util = require('./Z2B_Utilities');
const financeCoID = 'easymoney@easymoneyinc.com';
const config = require('../../../env.json');
var chainEvents = false;



/**
 * get chain info
 * @param {express.req} req - the inbound request object from the client
 * @param {express.res} res - the outbound response object for communicating back to client
 * @param {express.next} next - an express service to enable post processing prior to responding to the client
 * @function
 */
exports.getChainInfo = function(req, res, next) {
    var channel = {};
    var client = null;
    var peer = null;
    var wallet_path = path.join(__dirname, 'creds');
    console.log(wallet_path);
    Promise.resolve().then(() => {
        //
        // As of 9/28/2017 there is a known and unresolved bug in HyperLedger Fabric
        // https://github.com/hyperledger/composer/issues/957
        // this requires that the file location for the wallet for Fabric version 1.0 be in the following location: 
        // {HOME}/.hfc-key-store
        // therefore the wallet location will be ignored and any private keys required to enroll a user in this process 
        // must be located in {HOME}/.hfc-key-store
        // this is currently managed for you in the installation exec by copying the private key for PeerAdmin to this location
        //
        console.log("Create a client and set the wallet location");
        client = new hfc();
        return hfc.newDefaultKeyValueStore({ path: wallet_path })
        .then((wallet) => {
            console.log("Setting wallet");
            client.setStateStore(wallet);

            var crypto_suite = hfc.newCryptoSuite();
            // use the same location for the state store (where the users' certificate are kept)
            // and the crypto store (where the users' keys are kept)
            var crypto_store = hfc.newCryptoKeyStore({path: wallet_path});
            crypto_suite.setCryptoKeyStore(crypto_store);
            client.setCryptoSuite(crypto_suite);

            // change PeerAdmin in following line to adminID
            return client.getUserContext(config.composer.PeerAdmin, true);
        })
        .then((user) => {
            if (user === null || user === undefined || user.isEnrolled() === false) {
                console.error("User not defined, or not enrolled - error");
            }
            console.log("Setting channel");
            const homedir = require('os').homedir();
            var pemOrdererPath = path.join(homedir, 'cacertscomposer', 'admin', 'msp', 'cacerts', 'rca-org1-mplescano-com-7054.pem');
            var pemPeerPath = path.join(homedir, 'cacertscomposer', 'admin', 'msp', 'cacerts', 'rca-org2-mplescano-com-7054.pem');
            var pemOrderer = fs.readFileSync(pemOrdererPath).toString();
            var pemPeer = fs.readFileSync(pemPeerPath).toString();

            channel = client.newChannel(config.fabric.channelName);
            peer = client.newPeer(config.fabric.peerRequestURL, {'pem': pemPeer});
            channel.addPeer(peer);
            channel.addOrderer(client.newOrderer(config.fabric.ordererURL, {'pem': pemOrderer}));
        })
        .then(() => {
            console.log("Quering channel");
            return channel.queryInfo()
            .then((blockchainInfo) => {
                if (blockchainInfo) {
                    res.send({"result": "success", "currentHash": blockchainInfo.currentBlockHash.toString("hex"), blockchain: blockchainInfo});
                } else {
                    console.log('response_payload is null');
                    res.send({"result": "uncertain", "message": 'response_payload is null'});
                }
            })
            .catch((_err) => {
                console.log("queryInfo failed with _err = ", _err);
                res.send({"result": "failed", "message": _err.message});
            });     
        });
    });
}

/**
 * get chain events
 * @param {express.req} req - the inbound request object from the client
 * @param {express.res} res - the outbound response object for communicating back to client
 * @param {express.next} next - an express service to enable post processing prior to responding to the client
 * @function
 */
exports.getChainEvents = function(req, res, next) {
    if (chainEvents) {res.send({'port': svc.cs_socketAddr});}
    else
    {
        var channel = {};
        var client = null;
        var wallet_path = path.join(__dirname, 'creds');
        Promise.resolve().then(() => {
            client = new hfc();
            return hfc.newDefaultKeyValueStore({ path: wallet_path })
            .then((wallet) => {
                client.setStateStore(wallet);

                var crypto_suite = hfc.newCryptoSuite();
                // use the same location for the state store (where the users' certificate are kept)
                // and the crypto store (where the users' keys are kept)
                var crypto_store = hfc.newCryptoKeyStore({path: wallet_path});
                crypto_suite.setCryptoKeyStore(crypto_store);
                client.setCryptoSuite(crypto_suite);

                // change PeerAdmin in following line to adminID
                return client.getUserContext(config.composer.PeerAdmin, true);})
                .then((user) => {
                    if (user === null || user === undefined || user.isEnrolled() === false) 
                        {console.error("User not defined, or not enrolled - error"); return;}
                        const homedir = require('os').homedir();
                        var pemOrdererPath = path.join(homedir, 'cacertscomposer', 'admin', 'msp', 'cacerts', 'rca-org1-mplescano-com-7054.pem');
                        var pemPeerPath = path.join(homedir, 'cacertscomposer', 'admin', 'msp', 'cacerts', 'rca-org2-mplescano-com-7054.pem');
                        var pemOrderer = fs.readFileSync(pemOrdererPath).toString();
                        var pemPeer = fs.readFileSync(pemPeerPath).toString();

                        channel = client.newChannel(config.fabric.channelName);
                        var peer = client.newPeer(config.fabric.peerRequestURL, {'pem': pemPeer});
                        channel.addPeer(peer);
                        channel.addOrderer(client.newOrderer(config.fabric.ordererURL, {'pem': pemOrderer})); 
                        // change Admin in following line to admin
                        //var pemPath = path.join(__dirname,'creds','admin-peer-org2-mplescano-com');
                        //var adminPEM = JSON.parse(fs.readFileSync(pemPath)).certificate;

                        //var bcEvents = new hfcEH(client);
                        //bcEvents.setPeerAddr(config.fabric.peerEventURL, {pem: adminPEM});
                        var bcEvents = channel.newChannelEventHub(peer);
                        bcEvents.connect();
                        svc.createChainSocket();
                        bcEvents.registerBlockEvent(function(event) {svc.cs_connection.sendUTF(JSON.stringify(event));});
                        chainEvents = true;
                        res.send({'port': svc.cs_socketAddr});                    
                    })
            });
        }
}
