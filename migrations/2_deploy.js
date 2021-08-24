const Token = artifacts.require("Token");
const dBank = artifacts.require("dBank");

module.exports = async function(deployer) {
	//Deploy Token
	await deployer.deploy(Token)
	
	//Assign token into variable to get it's address
	const token = await Token.deployed()
	
	//Pass token address for dBank contract(for future minting)
	await deployer.deploy(dBank, token.address)

	//Assign dBank contract into variable to get it's address
	const dbank = await dBank.deployed()

	//Change token's owner/minter from deployer to dBank
	await token.passMinterRole(dbank.address)

};