# Aptos Poker

Aptos Poker is a privacy-preserving Texas Hold'em poker game implemented on the Aptos blockchain using homomorphic encryption. This project demonstrates how to create a decentralized poker game while maintaining player privacy.

## Features

- Decentralized poker game running on the Aptos blockchain
- Privacy-preserving gameplay using homomorphic encryption
- TypeScript SDK for easy integration with frontend applications
- React-based frontend for user interaction

## Project Structure

- `move/`: Smart contracts written in Move
  - `sources/`: Contains the main game logic and encryption modules
  - `tests/`: Contains test files for the Move modules
- `sdk/`: TypeScript SDK for interacting with the smart contracts
- `frontend/`: React-based frontend application

## Prerequisites

- Aptos CLI
- Node.js and npm/yarn
- Rust (for Aptos Move development)

## Setup

1. Clone the repository:
   ```
   git clone https://github.com/andrew54068/aptos-poker.git
   cd aptos-poker
   ```

2. Install dependencies:
   ```
   yarn install
   ```

3. Compile Move contracts:
   ```
   aptos move compile --package-dir move
   ```

4. Run Move tests:
   ```
   aptos move test --package-dir move
   ```

5. Start the frontend:
   ```
   cd frontend
   yarn start
   ```

## Usage

1. Create a game using the SDK or frontend interface.
2. Join the game with multiple players.
3. Place bets and play hands of Texas Hold'em poker.
4. The game logic and bet amounts are kept private using homomorphic encryption.

## Security Considerations

This project uses a simplified homomorphic encryption scheme for demonstration purposes. In a production environment, you should use a more robust and secure homomorphic encryption library.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This project is for educational purposes only. Please ensure you comply with all relevant laws and regulations when using or adapting this code.