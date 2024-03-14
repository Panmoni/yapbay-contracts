import os

contracts = [
    "Account.sol",
    "Arbitration.sol",
    "Escrow.sol",
    "Offer.sol",
    "Rating.sol",
    "Reputation.sol",
    "Trade.sol",
    "ContractRegistry.sol"
]

xml_content = "<documents>\n"

for index, contract in enumerate(contracts, start=1):
    file_path = os.path.join('.', contract)
    with open(file_path, 'r') as file:
        contract_content = file.read()
        xml_content += f"\t<document index=\"{index}\">\n"
        xml_content += f"\t\t<source>{contract}</source>\n"
        xml_content += f"\t\t<document_content>{contract_content}</document_content>\n"
        xml_content += "\t</document>\n"

xml_content += "</documents>"

with open("contracts.xml", 'w') as xml_file:
    xml_file.write(xml_content)
