module.exports = {
  root: true,
  env: { es2020: true, node: true },
  parser: "@typescript-eslint/parser",
  plugins: ["@typescript-eslint"],
  extends: ["eslint:recommended"],
  ignorePatterns: ["lib/**"],
  parserOptions: {
    ecmaVersion: 2020,
    sourceType: "module",
  },
  rules: {
    "max-len": "off",
    "require-jsdoc": "off",
    "object-curly-spacing": "off",
  },
};
