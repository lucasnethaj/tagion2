# Initialize Genesis Epoch

*Intialize bills* [Initialize DART](/documents/network_setup/initialize_dart.md)

## Create the epoch genesis data
The Genesis infomation is generated with stiefel command.

A list of node identifier `node_name_record,pubkey,address` should be create.

Atleast number active node N should be defined.

Here is an example with two node indetifers **(Note in practist the minimun should be 5)**

Example.
```
stiefel -p node_name_1,@XfA0RRS0ayy31OUHos807Vw80j_G8WQx7Ddh_JXJWm0=,ftp://ftp.smart.com -p node_name_2,@Ql-fwHnQrq9tD8V9fCLeI7QNoL1YR1qvIbRf8yD0etY=,http://tagion.org -o recorder_genesis.hibon
````

## Add the genesis data to the DART.

Apply the `recorder_genesis.hibon` create by `stiefel`.
```
dartutil dart.drt recorder_small.hibon -m
```

List inspect the DART content.

```
dartutil dart.drt --print

EYE: 462ee54f0468b9de0456c56642c8e59e71c3a52397a907013fd7949ee9f3542c
| 0A [12]
| .. | B7 [11]
| .. | .. 0ab74466913a7abef3afb6bda64bd296c7a5a758ae0e74aca89d512d2a995eaa [10] #
| 28 [15]
| .. | 59 [14]
| .. | .. 28591ef9f6ca1c608b850b58ba30f483f8d32d5bd3d8868affed85877b8f5243 [13] #
| 41 [18]
| .. | D9 [17]
| .. | .. 41d9b3fc497d6847ee67e87cfcbac1c9840d3173750d6c3f467962644f719a16 [16] #
| 42 [3]
| .. | 5F [2]
| .. | .. 425f9fc079d0aeaf6d0fc57d7c22de23b40da0bd58475aaf21b45ff320f47ad6 [1]
| 5D [6]
| .. | F0 [5]
| .. | .. 5df0344514b46b2cb7d4e507a2cf34ed5c3cd23fc6f16431ec3761fc95c95a6d [4]
| B1 [21]
| .. | 8D [20]
| .. | .. b18d0ce74b5383b888ea7e115f5ddae75482ae0d436bb7a57ac22cdd9811cff9 [19] #
| FE [24]
| .. | 9F [23]
| .. | .. fe9fb2737fde1dac8ec0815142381ff9e26a2fdf5e2b73a956dd6b6b5283f7d3 [22] #
```
