module.exports = {
  root: true,
  env: { es2020: true, node: true },
  extends: ["eslint:recommended"],
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