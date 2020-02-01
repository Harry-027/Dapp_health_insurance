const HealthInsurance = artifacts.require("HealthInsuranceIncentive");

module.exports = function (deployer) {
    deployer.deploy(HealthInsurance, 1, "Hyderabad");
};
