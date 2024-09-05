import React from 'react';
import { Game } from './components/Game';
import { AptosClient, AptosAccount } from "aptos";

function App() {
  const [client, setClient] = React.useState<AptosClient | null>(null);
  const [account, setAccount] = React.useState<AptosAccount | null>(null);

  React.useEffect(() => {
    const initAptos = async () => {
      const client = new AptosClient('https://fullnode.devnet.aptoslabs.com/v1');
      const account = new AptosAccount(); // In a real app, you'd load an existing account or create a new one
      setClient(client);
      setAccount(account);
    };
    initAptos();
  }, []);

  return (
    <div className="App">
      <h1>Aptos Poker</h1>
      {client && account && <Game client={client} account={account} />}
    </div>
  );
}

export default App;