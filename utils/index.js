const TIMEOUT_MS = 3000;

module.exports = {
    pt: (tx) => {
        return new Promise((resolve) => {
            tx.then((result) => result.wait()).then((receipt) => {
                setTimeout(() => resolve(receipt), TIMEOUT_MS);
            });
        });
    },
    oppositeChain: (networkName) => {
        return networkName === "arbgoerli" ? "optimismgoerli" : "arbgoerli";
    },
};
