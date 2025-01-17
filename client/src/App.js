import React, { useState, useEffect } from 'react';
import Web3 from 'web3';
import contractABI from './CrowdfundingABI.json';

function App() {
  console.log("App Component is rendering..."); 

  // Θα εμφανίζεται σε κάθε render (π.χ. αν αλλάξει κάποιο state).

  const [web3, setWeb3] = useState(null);
   const [accounts, setAccounts] = useState([]);

   const [contract, setContract] = useState(null);

  const [owner, setOwner] = useState('');


  const [contractAddress, setContractAddress] = useState('0x5fbdb2315678afecb367f032d93f642f64180aa3');   
  const [contractBalance, setContractBalance] = useState('0');   


  const [isActive, setIsActive] = useState(false);

  const [newTitle, setNewTitle] = useState('');
  const [newPledgeCost, setNewPledgeCost] = useState('');
  const [newPledgesNeeded, setNewPledgesNeeded] = useState('');


  const [activeCampaigns, setActiveCampaigns] = useState([]);  

  // ----------------------------------------------------------------
  // useEffect -> init() : ζητά άδεια από Metamask, αρχικοποιεί web3
  // ----------------------------------------------------------------


  useEffect(() => {
    console.log("useEffect [] is called -> init()");
    init();
  }, []);




  async function init() {

    console.log("init() called");
    if (window.ethereum) {
      try {
        console.log("Requesting accounts from Metamask...");     
        const _web3 = new Web3(window.ethereum);

        await window.ethereum.request({ method: 'eth_requestAccounts' });       
        const _accounts = await _web3.eth.getAccounts();

        setWeb3(_web3);

        setAccounts(_accounts);

        console.log("Metamask accounts:", _accounts);
      } catch (err) {   
        console.error("User denied accounts access or other error:", err);
      } 
    } else {
      alert("Please install Metamask!");           
    }
  }

  // ----------------------------------------------------------------
  // Connect Contract: δημιουργεί το contract instance & φέρνει πληροφορίες

  // ----------------------------------------------------------------
  async function connectContract() {


    console.log("connectContract() was called");

    if (!web3) {                 
      alert("Web3 is not initialized!");       
      return;
    }
    if (!contractAddress) {   
      alert("Please set the contract address first!");     
      return;
    }
    try {
      console.log("Creating contract instance with address:", contractAddress);
       
      const _contract = new web3.eth.Contract(contractABI.abi, contractAddress);
      setContract(_contract);   
   
      console.log("Fetching contract info (owner, isActive, balance, campaigns)...");   
      const _owner = await _contract.methods.owner().call();

      setOwner(_owner);

      const _active = await _contract.methods.isContractActive().call();     
      setIsActive(_active);

      const bal = await web3.eth.getBalance(contractAddress);
      setContractBalance(web3.utils.fromWei(bal, 'ether'));
         
  
      const campaigns = await _contract.methods.getActiveCampaigns().call();
      setActiveCampaigns(campaigns);
   
      alert("Contract connected successfully!");     
      console.log("Contract connected successfully!");   
    } catch (err) {     
      console.error("connectContract() error:", err);   
    }
  }


  // ----------------------------------------------------------------
  // createCampaign: καλεί την Solidity συνάρτηση createCampaign
  // ----------------------------------------------------------------
  async function createCampaign() {    
    console.log("createCampaign() was called");   
    if (!contract) {
      alert("Contract not connected!");
      return;
    }
    if (!accounts[0]) {   
      alert("No Metamask account found!");
      return;
    }   
    try {   
      console.log("Sending createCampaign() transaction...");
      await contract.methods.createCampaign(
        newTitle,
        newPledgeCost,
        newPledgesNeeded   
      ).send({
        from: accounts[0],
        value: web3.utils.toWei("0.02", "ether")
      });  
      alert("Campaign created!");    

      console.log("Refreshing campaigns list and contract balance...");
      const campaigns = await contract.methods.getActiveCampaigns().call();   
      setActiveCampaigns(campaigns);

      const bal = await web3.eth.getBalance(contractAddress);
      setContractBalance(web3.utils.fromWei(bal, 'ether'));  

    } catch (err) {
      console.error("createCampaign() error:", err);   
      alert("Error creating campaign: " + err.message);
    }
  }

  // ----------------------------------------------------------------

  // pledge: αγορά “μετοχών” σε υπάρχουσα καμπάνια

  // ----------------------------------------------------------------   
  async function pledge(campaignId, shares) {
    console.log("pledge() was called for campaignId:", campaignId);
     
    if (!contract) {
      alert("Contract not connected!");    
      return;
    }
    if (!accounts[0]) {
      alert("No Metamask account found!");

      return;  
    }

    try {
      console.log("Fetching campaign details to calculate cost...");
      const details = await contract.methods.getCampaignDetails(campaignId).call();

      const cost = details.pledgeCost; 
      console.log("pledgeCost from contract:", cost, "(wei)");
      const totalValue = (BigInt(cost) * BigInt(shares)).toString();


      console.log("Sending pledge() transaction with value:", totalValue, "wei");
      await contract.methods.pledge(campaignId, shares).send({

        from: accounts[0],
        value: totalValue
      });   

      alert("Pledge successful!");   
      console.log("Pledge transaction completed, refreshing data...");   

      const campaigns = await contract.methods.getActiveCampaigns().call();

      setActiveCampaigns(campaigns);   
  
      const bal = await web3.eth.getBalance(contractAddress);  
      setContractBalance(web3.utils.fromWei(bal, 'ether'));     

    } catch (err) {
      console.error("pledge() error:", err);   
      alert("Error pledging: " + err.message);   
    }
  }

  // ----------------------------------------------------------------
  // Render  
  // ----------------------------------------------------------------
  return (
    <div style={{ padding: 20 }}>    
      <h2>Crowdfunding DApp</h2>     
      
      <div>
        <p><b>Current Account:</b> {accounts[0]}</p>
        <p>
          <b>Contract Address:</b>
          <input 
            style={{ marginLeft: 5 }}  
            value={contractAddress}
            onChange={(e) => {
              setContractAddress(e.target.value);
              console.log("contractAddress changed to", e.target.value);
            }}    
          />
          <button onClick={connectContract} style={{ marginLeft: 5 }}>
            Connect Contract
          </button>   
        </p>
        <p><b>Owner:</b> {owner}</p>   
        <p><b>Contract Active:</b> {isActive ? 'Yes' : 'No'}</p>   
        <p><b>Contract Balance (ETH):</b> {contractBalance}</p>

      </div>

      <hr />

      <h3>New Campaign</h3>
      <div>
        <label>Title: </label>
        <input onChange={e => {
          setNewTitle(e.target.value);     
          console.log("newTitle changed to", e.target.value);
        }} />
        <br />   
        <label>Pledge Cost (wei): </label>
        <input onChange={e => {
          setNewPledgeCost(e.target.value);
          console.log("newPledgeCost changed to", e.target.value);   
        }} />
        <br />
        <label>Pledges Needed: </label>
        <input onChange={e => {    
          setNewPledgesNeeded(e.target.value);
          console.log("newPledgesNeeded changed to", e.target.value);
        }} />
        <br />
        <button onClick={createCampaign}>Create (cost 0.02 ETH)</button>
      </div>    

      <hr />

      <h3>Active Campaigns</h3>
      {activeCampaigns.map((c, index) => {   
        return (
          <div key={index} style={{ border: '1px solid gray', margin: 5, padding: 5 }}>   
            <p><b>ID:</b> {c.campaignId}</p>  
            <p><b>Title:</b> {c.title}</p>  
            <p><b>Entrepreneur:</b> {c.entrepreneur}</p>  
            <p><b>PledgeCost:</b> {c.pledgeCost.toString()}</p>
            <p><b>Needed:</b> {c.pledgesNeeded.toString()}</p>  
            <p><b>Count:</b> {c.pledgesCount.toString()}</p>

            <button onClick={() => pledge(c.campaignId, 1)}>Pledge 1 share</button>
          </div>  
        );
      })}
    </div>
  );

  
}

export default App;
