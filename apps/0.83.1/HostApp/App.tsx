import React from 'react';
import {Text, View} from 'react-native';
import RTNTestableModule from 'rtn-testable-module';

// The Matrix never actually mounts this app at runtime; it exists so JS-level
// autolinking has something to import and so codegen sees the module spec.
// The CMake tests drive the TurboModule directly via TurboModuleTestingEnvironment.

export default function App(): React.JSX.Element {
  const result = RTNTestableModule.concat([1, 2, 3], '-');
  return (
    <View>
      <Text>{result}</Text>
    </View>
  );
}
