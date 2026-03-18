module.exports = function (api) {
  api.cache(true);
  return {
    presets: ['babel-preset-expo'],
    plugins: [
      // react-native-reanimated v4 plugin (lives in plugin/ subdir)
      require.resolve('react-native-reanimated/plugin'),
    ],
  };
};
