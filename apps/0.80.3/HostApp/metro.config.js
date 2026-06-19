const path = require('path');
const {getDefaultConfig, mergeConfig} = require('@react-native/metro-config');

// __dirname here resolves to apps/<version>/HostApp at runtime.
// Three levels up reaches the matrix root, where RTNTestableModule lives.
const matrixRoot = path.resolve(__dirname, '..', '..', '..');
const rtnTestableModule = path.join(matrixRoot, 'RTNTestableModule');

/** @type {import('@react-native/metro-config').MetroConfig} */
const config = {
  watchFolders: [rtnTestableModule],
  resolver: {
    unstable_enableSymlinks: true,
    nodeModulesPaths: [path.resolve(__dirname, 'node_modules')],
  },
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);
