const express = require('express');
const app = express();
const port = 3000;

const cors = require('cors');

// allow from everywhere
app.use(cors(
    {
        origin: '*'
    }
))

app.use(express.json()); // Add this line to parse JSON data


const array = [ { id: 1, client: "0xd193ba8aaE6f4909e0c1e0155f91A6e74F6B4ba4", freelancer: "0x2A52c31958Bcc72680991373daC2EBf482b610f2", chatId: "a73612d6d14afd9f8420c24d970717e6b83cc45a6d0fe6ace8e0527977c491a3" }, { id: 2 } ];

//check if client has already an order

app.get('/calculateFee', (req, res) => {
    // calculate fee
    // return fee
});

app.get('/fetchArray', (req, res) => {
    res.send(array);
});

app.post('/addToArray', (req, res) => {
  const { clientAddress, freelancerAddress, chatId } = req.body;


  //check if client has already an order ( check from array)
  const chatItem = array.find((item) => item.client === clientAddress && item.freelancer === freelancerAddress);

  console.log(chatItem)

  if(!chatItem) {

    const id = array.length + 1;

    array.push({
      id,
      client: clientAddress,
      freelancer: freelancerAddress,
      chatId
    });
  
    res.send(array);

  } else {
    res.send('already exists');
  }



});

// Define the "/hello" route
app.get('/order', (req, res) => {
    
  // client puts money into smart contract ( with extra 10$)
  // notify developer that order is placed
  // return order id
});

app.get('/order/:id', (req, res) => {
    // return order details
});

app.get('/order/:id/confirm', (req, res) => {
    // client confirms that order is received
    // set isCompleted to true
    // notify developer that order is completed
});

app.get('/order/:id/cancel', (req, res) => {
    // client cancels order
    // set isCancelled to true
    // notify developer that order is cancelled
});




// Start the server
app.listen(port, () => {
  console.log(`Example app listening at http://localhost:${port}`);
});
