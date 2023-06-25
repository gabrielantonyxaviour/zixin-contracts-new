const { types } = require("hardhat/config")
const { networks } = require("../networks")
const fs = require("fs")
task("functions-deploy-zixin", "Deploys the Zixin Contracts")
  .addOptionalParam("verify", "Set to true to verify client contract", true, types.boolean)
  .setAction(async (taskArgs) => {
    if (network.name === "hardhat") {
      throw Error(
        'This command cannot be used on a local hardhat chain.  Specify a valid network or simulate an FunctionsConsumer request locally with "npx hardhat functions-simulate".'
      )
    }

    console.log(`Deploying Zixin  to ${network.name}`)

    console.log("\n__Compiling Contracts__")
    await run("compile")
    if (network.name === "polygonMumbai") {
      const oracleAddress = networks[network.name]["functionsOracleProxy"]
      const zixinContractFactory = await ethers.getContractFactory("ZixinPolygon")
      const zixinPolygon = await zixinContractFactory.deploy(
        oracleAddress,
        networks[network.name]["gateWayAddress"],
        "0x71B43a66324C7b80468F1eE676E7FCDaF63eB6Ac"
      )
      console.log(
        `\nWaiting ${networks[network.name].confirmations} blocks for transaction ${
          zixinPolygon.deployTransaction.hash
        } to be confirmed...`
      )
      await zixinPolygon.deployTransaction.wait(networks[network.name].confirmations)
      const verifyContract = taskArgs.verify

      if (verifyContract && !!networks[network.name].verifyApiKey && networks[network.name].verifyApiKey !== "UNSET") {
        try {
          console.log("\nVerifying contract...")
          await zixinPolygon.deployTransaction.wait(Math.max(6 - networks[network.name].confirmations, 0))
          await run("verify:verify", {
            address: zixinPolygon.address,
            constructorArguments: [
              oracleAddress,
              networks[network.name]["gateWayAddress"],
              "0x71B43a66324C7b80468F1eE676E7FCDaF63eB6Ac",
            ],
          })
          console.log("Contract verified")
        } catch (error) {
          if (!error.message.includes("Already Verified")) {
            console.log("Error verifying contract.  Delete the build folder and try again.")
            console.log(error)
          } else {
            console.log("Contract already verified")
          }
        }
      } else if (verifyContract) {
        console.log(
          "\nPOLYGONSCAN_API_KEY, ETHERSCAN_API_KEY or SNOWTRACE_API_KEY is missing. Skipping contract verification..."
        )
      }
      console.log(`\Zixin deployed to ${zixinPolygon.address} on ${network.name}`)
    } else {
      const zixinContractFactory = await ethers.getContractFactory("ZixinGeneral")
      const zixinGeneral = await zixinContractFactory.deploy(
        "Zixin " + network.name.charAt(0).toUpperCase() + network.name.slice(1),
        "Z" + network.name[0].toUpperCase(),
        networks[network.name]["gateWayAddress"],
        "0x71B43a66324C7b80468F1eE676E7FCDaF63eB6Ac"
      )
      console.log(
        `\nWaiting ${networks[network.name].confirmations} blocks for transaction ${
          zixinGeneral.deployTransaction.hash
        } to be confirmed...`
      )
      await zixinGeneral.deployTransaction.wait(networks[network.name].confirmations)
      const verifyContract = taskArgs.verify

      if (verifyContract && !!networks[network.name].verifyApiKey && networks[network.name].verifyApiKey !== "UNSET") {
        try {
          console.log("\nVerifying contract...")
          await zixinGeneral.deployTransaction.wait(Math.max(6 - networks[network.name].confirmations, 0))
          await run("verify:verify", {
            address: zixinGeneral.address,
            constructorArguments: [
              "Zixin " + network.name.charAt(0).toUpperCase() + network.name.slice(1),
              "Z" + network.name[0].toUpperCase(),
              networks[network.name]["gateWayAddress"],
              "0x71B43a66324C7b80468F1eE676E7FCDaF63eB6Ac",
            ],
          })
          console.log("Contract verified")
        } catch (error) {
          if (!error.message.includes("Already Verified")) {
            console.log("Error verifying contract.  Delete the build folder and try again.")
            console.log(error)
          } else {
            console.log("Contract already verified")
          }
        }
      } else if (verifyContract) {
        console.log(
          "\nPOLYGONSCAN_API_KEY, ETHERSCAN_API_KEY or SNOWTRACE_API_KEY is missing. Skipping contract verification..."
        )
      }
      console.log(`\Zixin deployed to ${zixinGeneral.address} on ${network.name}`)
    }
  })
