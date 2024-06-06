// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IUniswapV2Router01} from "../../vendor/IUniswapV2Router01.sol";
import {IUniswapV2Factory} from "../../vendor/IUniswapV2Factory.sol";
import {AStaticUSDCData, IERC20} from "../../abstract/AStaticUSDCData.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract UniswapAdapter is AStaticUSDCData {
    error UniswapAdapter__TransferFailed();

    using SafeERC20 for IERC20;

    IUniswapV2Router01 internal immutable i_uniswapRouter;
    IUniswapV2Factory internal immutable i_uniswapFactory;

    address[] private s_pathArray;

    event UniswapInvested(uint256 tokenAmount, uint256 wethAmount, uint256 liquidity);
    event UniswapDivested(uint256 tokenAmount, uint256 wethAmount);

    constructor(address uniswapRouter, address weth, address tokenOne) AStaticUSDCData(weth, tokenOne) {
        i_uniswapRouter = IUniswapV2Router01(uniswapRouter);
        i_uniswapFactory = IUniswapV2Factory(IUniswapV2Router01(i_uniswapRouter).factory());
    }

    // slither-disable-start reentrancy-eth
    // slither-disable-start reentrancy-benign
    // slither-disable-start reentrancy-events

    // note - Let's say the token is weth and the amount is 25% of that asset (say, 25% of 10 weth = 2.5 weth)
    function _uniswapInvest(IERC20 token, uint256 amount) internal {

        // note - token is weth and couterPartyToken is usdc
        IERC20 counterPartyToken = token == i_weth ? i_tokenOne : i_weth;

        // We will do half in WETH and half in the token
        
        // note - 1.25 weth is the amountOfTokenToSwap
        uint256 amountOfTokenToSwap = amount / 2;

        // note - pathArray = [weth, usdc]
        s_pathArray = [address(token), address(counterPartyToken)];

        // note - Weth Vault is approving uniswap router to spend 2.5 weth (remaining 2.5 weth in the contract)
        bool succ = token.approve(address(i_uniswapRouter), amountOfTokenToSwap);
        if (!succ) {
            revert UniswapAdapter__TransferFailed();
        }

        // note - Swapping weth to usdc (2.5 weth will be taken out of the contract and the worth in usdc will be sent to  the contract.)

        // note amounts = [2.5 weth, 200 usdc]
        uint256[] memory amounts = i_uniswapRouter.swapExactTokensForTokens({
            amountIn: amountOfTokenToSwap,
            amountOutMin: 0,
            path: s_pathArray,
            to: address(this),
            deadline: block.timestamp
        });

        // note - At this point, I now have (let' say 2.5 weth = 200 usdc) 200 usdc in the contract and 2.5 weth
        succ = counterPartyToken.approve(address(i_uniswapRouter), amounts[1]);

        
        if (!succ) {
            revert UniswapAdapter__TransferFailed();
        }

        // note - Approving the contract to spend 2.5weth + 2.5 weth = 5 weth (whereas, the contract only has 2.5 weth and 200 usdc)
        succ = token.approve(address(i_uniswapRouter), amountOfTokenToSwap + amounts[0]);
        if (!succ) {
            revert UniswapAdapter__TransferFailed();
        }

        // amounts[1] should be the WETH amount we got back
        // q - Why are you trying to add liquidity with 5 weth with 200 usdc
        (uint256 tokenAmount, uint256 counterPartyTokenAmount, uint256 liquidity) = i_uniswapRouter.addLiquidity({
            tokenA: address(token),
            tokenB: address(counterPartyToken),
            amountADesired: amountOfTokenToSwap + amounts[0],
            amountBDesired: amounts[1],
            amountAMin: 0,
            amountBMin: 0,
            to: address(this),
            deadline: block.timestamp
        });
        emit UniswapInvested(tokenAmount, counterPartyTokenAmount, liquidity);
    }


    // @note - This will send the liquidity token back to uniswap, in return, the vault will get back the asset and weth. The weth is then converted to asset. 
    function _uniswapDivest(IERC20 token, uint256 liquidityAmount) internal returns (uint256 amountOfAssetReturned) {
        IERC20 counterPartyToken = token == i_weth ? i_tokenOne : i_weth;

        (uint256 tokenAmount, uint256 counterPartyTokenAmount) = i_uniswapRouter.removeLiquidity({
            tokenA: address(token),
            tokenB: address(counterPartyToken),
            liquidity: liquidityAmount,
            amountAMin: 0,
            amountBMin: 0,
            to: address(this),
            deadline: block.timestamp
        });

        // @note - We are basically trying to convert back to the asset.
        s_pathArray = [address(counterPartyToken), address(token)];
        uint256[] memory amounts = i_uniswapRouter.swapExactTokensForTokens({
            amountIn: counterPartyTokenAmount,
            amountOutMin: 0,
            path: s_pathArray,
            to: address(this),
            deadline: block.timestamp
        });
        emit UniswapDivested(tokenAmount, amounts[1]);
        amountOfAssetReturned = amounts[1];
    }
    // slither-disable-end reentrancy-benign
    // slither-disable-end reentrancy-events
    // slither-disable-end reentrancy-eth
}
