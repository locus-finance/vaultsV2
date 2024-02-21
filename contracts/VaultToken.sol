// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IBaseVault} from "./interfaces/IBaseVault.sol";

error VaultToken__PremintFailed(address user, uint256 amount);

contract VaultToken is
    Initializable,
    ERC20Upgradeable,
    UUPSUpgradeable,
    AccessControlUpgradeable
{
    function initialize(
        address _admin,
        address _vault
    ) external initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __ERC20_init("Locus Yield USD", "xUSD");
        _grantRole(ADMIN, _admin);
        _grantRole(VAULT, _vault);
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant VAULT = keccak256("VAULT");
    IBaseVault public currentVault;

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(ADMIN) {}

    function mint(address to, uint256 amount) external onlyRole(VAULT) {
        _mint(to, amount);
    }

    function burn(address to, uint256 amount) external onlyRole(VAULT) {
        _burn(to, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function dispatch(address[] memory to, uint256[] memory amount) external{
        uint256 len = to.length;
        for (uint256 i; i < len; i++) {
            _transfer(_msgSender(), to[i], amount[i]);
        }
    }

    function setCurrentVault(address newVault) external onlyRole(ADMIN){
        currentVault = IBaseVault(newVault);
    }

    function pricePerShare() external view  returns (uint256 pps) {
        pps = currentVault.pricePerShare();
    }
}
