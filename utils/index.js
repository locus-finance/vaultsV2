module.exports = {
    getEnv(name) {
        const value = process.env[name];
        if (!value) {
            throw new Error(`Missing environment variable ${name}`);
        }
        return value;
    },
    oppositeChain: (networkName) => {
        if (
            networkName === "optimismgoerli" ||
            networkName === "polygonmumbai"
        ) {
            networkName === "optimismgoerli"
                ? "polygonmumbai"
                : "optimismgoerli";
        }

        if (networkName === "optimism" || networkName === "polygon") {
            networkName === "optimism" ? "polygon" : "optimism";
        }

        throw new Error("Chain not defined");
    },
    vaultChain: (networkName) => {
        if (
            networkName === "optimismgoerli" ||
            networkName === "polygonmumbai"
        ) {
            return "optimismgoerli";
        }

        if (networkName === "optimism" || networkName === "polygon" || networkName === "arbitrumOne" || networkName === "base") {
            return "optimism";
        }

        throw new Error("Vault not defined");
    },
};
