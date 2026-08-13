from setuptools import setup, find_packages

setup(
    name="akmena-sdk",
    version="2.1.0",
    description="The official Python SDK for the Akmena AI Agent Protocol",
    packages=find_packages(),
    install_requires=[
        "web3>=6.0.0",
        "eth-account>=0.8.0"
    ],
    python_requires=">=3.8",
)
