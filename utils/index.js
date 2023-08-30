module.exports = {
    getEnv(name) {
        const value = process.env[name];
        if (!value) {
            throw new Error(`Missing environment variable ${name}`);
        }
        return value;
    },
    oppositeChain: (networkName) => {
        return networkName === "optimismgoerli"
            ? "polygonmumbai"
            : "optimismgoerli";
    },
    vaultChain: (networkName) => {
        if (
            networkName === "optimismgoerli" ||
            networkName === "polygonmumbai"
        ) {
            return "optimismgoerli";
        }

        throw new Error("Vault not defined");
    },
};
