import { AptosClient, AptosAccount, Types } from "aptos";

export class Game {
    private client: AptosClient;
    private account: AptosAccount;

    constructor(client: AptosClient, account: AptosAccount) {
        this.client = client;
        this.account = account;
    }

    async createGame() {
        const payload: Types.TransactionPayload = {
            type: "entry_function_payload",
            function: `${this.account.address()}::game::create_game`,
            type_arguments: [],
            arguments: []
        };
        await this.client.generateSignSubmitTransaction(this.account, payload);
    }

    async joinGame(gameAddress: string) {
        const payload: Types.TransactionPayload = {
            type: "entry_function_payload",
            function: `${gameAddress}::game::join_game`,
            type_arguments: [],
            arguments: []
        };
        await this.client.generateSignSubmitTransaction(this.account, payload);
    }

    async bet(gameAddress: string, amount: number) {
        const payload: Types.TransactionPayload = {
            type: "entry_function_payload",
            function: `${gameAddress}::game::bet`,
            type_arguments: [],
            arguments: [amount]
        };
        await this.client.generateSignSubmitTransaction(this.account, payload);
    }

    // Add more methods as needed
}