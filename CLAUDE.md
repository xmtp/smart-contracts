# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build/Lint/Test Commands
- Build: `forge build`
- Test all: `forge test`
- Test single: `forge test --match-contract ContractName --match-test testFunctionName -vvv`
- Lint: `npm run solhint` or `yarn solhint`
- Format: `npm run prettier` or `yarn prettier`
- Static analysis: `npm run slither` or `yarn slither`

## Code Style Guidelines
- Follow checks-effects-interactions pattern
- Use internal instead of private visibility
- Functions should have single responsibility
- Exit early (use return/revert as early as possible)
- Name all return variables
- Natspec: @notice in interfaces, @dev for internal documentation
- Avoid boolean function arguments - create separate functions instead
- Use descriptive constants instead of magic literals
- Minimize indentation/nesting within functions
- Separate multiline code blocks with empty lines
- Variables should be simple and generic, without type or unit names
- Functions names should reflect scope - smaller names for broader functions
- Avoid declaring variables as interfaces or structs as memory when possible