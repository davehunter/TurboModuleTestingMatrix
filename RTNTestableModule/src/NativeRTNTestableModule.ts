import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  concat(array: Array<number>, separator: string): string;
}

export default TurboModuleRegistry.getEnforcing<Spec>(
  'NativeRTNTestableModule'
);