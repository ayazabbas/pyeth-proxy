# eth-rpc

eth-rpc is a Python API for proxying mainnet Ethereum RPC requests to leading RPC providers Alchemy, Infura and QuickNode. Requests are load-balanced across these RPC providers, and if any provider has issues, requests will gracefully fallback to another provider.
