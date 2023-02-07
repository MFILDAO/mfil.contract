const { ethers } = require("hardhat");
const dotenv = require("dotenv")
dotenv.config()


async function main() {
    const provider = (()=> {
        console.log(ethers);
        let JP = ethers.providers.JsonRpcProvider;
        let oldWt = JP.prototype._wrapTransaction;
        JP.prototype._wrapTransaction = function(tx, hash, startBlock)  {
            // console.log(this);
            return oldWt.call(this, tx, null, startBlock);
        }
        let p = new JP("https://api.hyperspace.node.glif.io/rpc/v1", 3141); // dev
        return p;
    })();

    const owner = new ethers.Wallet(process.env.PRIVATE_KEY, provider); // localhost testnet 
    // const [deployer] = await ethers.getSigners();
    const deployer = owner;

    let mconfigAddr = deployer.address;
    let overrides = {

    };
    let constructors = {
        "MConfig": (factory, create) => {
            return create.call(factory, overrides);
        },
        "MFacade":  (factory, create) => {
            return create.call(factory, mconfigAddr, overrides);
        },
        "MFil": function (factory, create) {
            return create.call(factory, mconfigAddr, "mfil", "mfil", overrides);
        },
        "MNft": function (factory, create) {
            return create.call(factory, mconfigAddr, "mnft", "mnft", overrides);
        },
        "MStaker": function (factory, create) {
            return create.call(factory, mconfigAddr, overrides);
        },
        "Fil2MfilAccount": function (factory, create) {
            return create.call(factory, overrides);
        },
        "Mfil2FilAccount": function (factory, create) {
            return create.call(factory, overrides);
        },
        "ProfitAccount": function (factory, create) {
            return create.call(factory, overrides);
        }
    }    

    let deployContract = async function (name) {
        var name_tmp = name
        if (name == "Fil2MfilAccount" || name == "Mfil2FilAccount" || name == "ProfitAccount") {
            name_tmp = "MAccount"
        }
        const factory = await ethers.getContractFactory(name_tmp, deployer);
        const contract = await constructors[name](factory, factory.deploy);
        const tx = contract.deployTransaction;
        console.log(name + ": " + contract.address);
        
        console.log("\ttx hash:", tx.hash);
        console.log("\ttx nonce:", tx.nonce);
        console.log("\ttx gasLimit:", ethers.utils.formatUnits(tx.gasLimit, "gwei"), "gwei");

        return contract;
    };

    // console.log(ethers.provider);
    console.log(
        "Deploying contracts with the account:",
        deployer.address
    );
    // const provider = new ethers.providers.AlchemyProvider(network, 'demo')

    let nonce = await provider.getTransactionCount(deployer.address);
    console.log("Account balance:", ethers.utils.formatUnits((await deployer.getBalance()).toString(), "ether"), "ether");
    console.log("Account nonce:", nonce);

    let feeData = await provider.getFeeData();
    if (feeData.lastBaseFeePerGas != null) {
        console.log("lastBaseFeePerGas:", ethers.utils.formatUnits(feeData.lastBaseFeePerGas, "gwei"), "gwei");
        console.log("maxFeePerGas:", ethers.utils.formatUnits(feeData.maxFeePerGas, "gwei"), "gwei");
        console.log("maxPriorityFeePerGas:", ethers.utils.formatUnits(feeData.maxPriorityFeePerGas, "gwei"), "gwei");
        console.log("gasPrice:", ethers.utils.formatUnits(feeData.gasPrice, "gwei"), "gwei");
    }
    
    try {
        const mconfig = await deployContract("MConfig");
        mconfigAddr = mconfig.address;

        const mfacade = await deployContract("MFacade",);

        const mfil = await deployContract("MFil");

        const mnft = await deployContract("MNft");

        const mstaker = await deployContract("MStaker");

        const fil2MfilAccount = await deployContract("Fil2MfilAccount");

        const mfil2FilAccount = await deployContract("Mfil2FilAccount");

        const profitAccount = await deployContract("ProfitAccount");
        
        await Promise.all([mconfig.deployed(), mfacade.deployed(), mnft.deployed(), mstaker.deployed(), 
                fil2MfilAccount.deployed(), mfil2FilAccount.deployed(), profitAccount.deployed()]);

        console.log("deploy over");

    } catch (e) {
        console.log("got error");
        console.log(e.message);
        console.log(e);
    }

    return;
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });