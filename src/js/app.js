App = {
  web3Provider: null,
  contracts: {},
  accounts: [],
  account: '0x0',
  contractInstance: null,
  recordPatientForm: null,
  content: null,
  fetchDetails: null,
  patientId: null,

  init: function () {
    App.recordPatientForm = $("#recordPatient");
    App.content = $("#content");
    App.fetchDetails = $("#fetchDetails");
    return App.initWeb3();
  },

  initWeb3: function () {
    App.web3Provider = new Web3.providers.HttpProvider('http://localhost:7545');
    web3 = new Web3(App.web3Provider);
    return App.initContract();
  },

  initContract: function () {
    $.getJSON("HealthInsuranceIncentive.json", function (smartInstance) {
      App.contracts.HealthInsurance = TruffleContract(smartInstance);
      App.contracts.HealthInsurance.setProvider(App.web3Provider);
      App.listenForEvents();
      return App.render();
    });
  },

  // Listen for events emitted from the contract
  listenForEvents: function () {
    App.contracts.HealthInsurance.deployed().then(function (instance) {
      instance.patientRecorded({}, {
        fromBlock: 0,
        toBlock: 'latest'
      }).watch(function (error, eventDetails) {
        $("#event").html("Event triggered: " + eventDetails.event);
      });
      instance.footStepsRecorded({}, {
        fromBlock: 0,
        toBlock: 'latest'
      }).watch(function (error, eventDetails) {
        $("#event").html("Event triggered: " + eventDetails.event);
      });
      instance.transactionCompleted({}, {
        fromBlock: 0,
        toBlock: 'latest'
      }).watch(function (error, eventDetails) {
        $("#event").html("Event triggered: " + eventDetails.event);
      });
    }).catch((err) => {
      console.log('error while contract deployment', err);
    })
  },

  render: function () {
    App.recordPatientForm.show();
    App.fetchDetails.hide();
    App.content.hide();

    // loading account details from Ganache
    web3.eth.getAccounts(function (err, accounts) {
      if (err === null) {
        App.accounts = accounts;
        App.account = accounts[0];
      }
    });
  },

  recordSteps: function () {
    var footsteps = $('#patientSelect').val();
    App.contracts.HealthInsurance.deployed().then(function (instance) {
      return instance.recordFootsteps(App.patientId, footsteps, { from: App.account, gas: 3000000 });
    }).then(function () {
      $("#confirmFootsteps").html("Footsteps recorded for the patient");
    });
  },

  storePenalty: function () {
    App.contracts.HealthInsurance.deployed().then(function (instance) {
      return instance.storePatientAmount(App.patientId, {
        from: App.accounts[App.patientId], gas: 3000000,
        value: web3.toWei(4, "ether")
      });
    }).then(function () {
      $("#confirmPenalty").html("Penalty Amount stored in Contract by the patient");
    });
  },

  settleIncentive: function () {
    App.contracts.HealthInsurance.deployed().then(function (instance) {
      return instance.settleRewards(App.patientId, {
        from: App.account, gas: 3000000,
        value: web3.toWei(20, "ether")
      });
    }).then(function () {
      $("#confirmIncentive").html("Incentive Amount settlement completed by the Insurance provider");
    });
  },

  patientDetails: function () {
    var patientId = $('#patientSelect').val();
    App.contracts.HealthInsurance.deployed().then(function (instance) {
      return instance.getPatientDetails(patientId);
    }).then(function (result) {
      var patientDetail = $("#patientDetails");
      patientDetail.empty();
      App.patientId = result[0].toNumber();
      var id = result[0].toNumber();
      var disease = result[1];
      var age = result[2].toNumber();
      var gender = result[3];
      var eligibility = result[4] ? 'yes' : 'no';
      var days = result[5].toNumber();
      var patientTemplate = "<tr><th>" + id + "</th><td>" + disease +
        "</td><td>" + age + "</td><td>" + gender + "</td><td>" + eligibility + "</td><td>" + days;
      patientDetail.append(patientTemplate);
      App.content.show();
      App.fetchDetails.hide();
    }).catch(function (err) {
        console.error('An error occurred while fetching patient details',err);
    });
  },

  recordPatient: function () {
    var id = $('#patientId').val();
    var disease = $('#disease').val();
    var gender = $('#gender').val();
    var age = $('#age').val();
    App.contracts.HealthInsurance.deployed().then(function (instance) {
      return instance.recordPatient(id, disease, gender, age, App.accounts[id], { from: App.account, gas: 3000000 });
    }).then(function () {
      App.recordPatientForm.hide();
      App.fetchDetails.show();
    }).catch(function (err) {
      console.error("An error occurred while recording patient details", err);
    });
  }
};

$(function () {
  $(window).load(function () {
    App.init();
  });
});