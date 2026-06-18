module.exports = {
  dependency: {
    platforms: {
      android: {
        sourceDir: 'android',
        packageImportPath: 'import com.rtntestablemodule.RTNTestableModulePackage;',
        packageInstance: 'new RTNTestableModulePackage()',
      },
    },
  },
};
