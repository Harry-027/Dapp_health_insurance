pragma solidity >=0.4.22 <0.6.0;

contract HealthInsuranceIncentive {


	event transactionCompleted(address _from, bool _val); // event confirming when event transaction is successfull
	event patientRecorded(uint _id, bool _val); // event confirming patient details successfully recorded.
	event footStepsRecorded(uint _id, bool _val); // event confirming patient footsteps successfully recorded.

    struct InsProvider {
	    uint id; // Id of insurance provider
	    string location; // location of insurance provider
	    address payable providerWallet; // wallet address of insurance provider
    }

    struct Patient {
    	uint id; // patient id
    	string disease; // patient disease
    	uint age; // patient age
    	string gender; // patient gender
    	mapping(uint => Footstep) footsteps; // footsteps for each day stored against day
    	address payable patientWallet; // patient wallet address
    	uint avg_fs_month; // average footsteps per month (30 days)
    	uint avg_fs_week; // average footsteps per week
    	uint total_fs; // sum of total steps till present day
    	bool ifEligible; // if the patient is eligible for incentive
    	bool isPatient; // if the patient exists
		uint daysCompleted; // to track the number of days completed recording footsteps
    	uint walletAmount; // holds the penalty amount, in case of penalty this will get deducted
    }

    struct Footstep {
	    uint steps; // number of footsteps per day
	    uint time; // time at which steps were recorded
    }

    mapping(uint => Patient) private patients; // will store instance of patient against its id

	uint private monthly_days = 30; // days in all months (assumption data)
	uint private weekly_days = 7; // days in a week
    uint private avg_fs_week_th = 5000; // average weekly threshold for footsteps
    InsProvider provider; // insurance provider instance to be initialized during contract deployment

	modifier onlyProvider() {
		require(provider.providerWallet == msg.sender, "Only provider can carry out this transaction");
		_;
	}

	modifier onlyPatient(uint patientId) {
		require(patients[patientId].patientWallet == msg.sender, "Only respective patient is allowed to carry out this transaction");
		_;
	}

    // to check if patient exits on blockchain
    modifier validPatient(uint patientId) {
    	require(patients[patientId].isPatient == true, "Given patientId doesn't exists in system"); // will revert in case patient does not exists
    	_;
    }

    // to check if number of steps provided are valid(non-negative)
    modifier validSteps(uint steps) {
        require(steps >= 0, "steps taken by patient can never be negative");
        _;
    }

    // to check if given number of days are valid
    modifier validDay(uint day) {
        require(day >= 0, "day  can take value from 1 to 30"); // assuming 30 days in a month
    	require(day <= 30, "day can take value from 1 to 30"); // assuming 30 days in a month
        _;
    }

    // to be invoked during contract deployment
    constructor(uint _id, string memory _location) public {
    	provider = InsProvider({
    		id: _id,
    		location: _location,
    		providerWallet: msg.sender
    	});
    }

    // to record the patient details on blockchain
    function recordPatient(uint patientId, string calldata disease, string calldata gender,
        uint age, address payable wallet) external onlyProvider returns (bool success) {
    	require(patients[patientId].isPatient == false, "Given patientId already exists in system"); // will revert in case patient exists
    	Patient memory patient = Patient({id: patientId, disease: disease, gender: gender, age: age, daysCompleted: 0,
            patientWallet: wallet, isPatient: true, ifEligible: true, avg_fs_week: 0, avg_fs_month: 0, total_fs: 0, walletAmount: 0 });
    	patients[patientId] = patient;
		emit patientRecorded(patientId, true);
    	return true;
    }

    // to store the penalty amount from patient in advance so to penalize him at a given condition
    function storePatientAmount(uint patientId) external payable validPatient(patientId) onlyPatient(patientId) returns (bool success) {
    	require(msg.value == 4 ether,"Invalid amount for patient penalty use case");
    	Patient storage patient = patients[patientId];
    	patient.walletAmount = msg.value;
		emit transactionCompleted(msg.sender, true);
    	return true;
    }


    // to record the patient footsteps & set his incentive eligibility criteria
    function recordFootsteps(uint patientId, uint steps) external validPatient(patientId) validSteps(steps) onlyProvider
    returns (bool success) {
    	Patient storage patient = patients[patientId];
    	require(patient.walletAmount == 4 ether, "Insufficient balance in patients account. Footsteps cannot be recorded");
    	require(patient.daysCompleted < monthly_days, "Records already updated for all the days");
		patient.daysCompleted++;
		Footstep memory footstep = Footstep({steps: steps, time: now});
    	patient.footsteps[patient.daysCompleted] = footstep;
    	patient.total_fs = patient.total_fs + steps; // total footsteps summation for a month
    	if(patient.daysCompleted >= weekly_days) {
    		uint totalSteps = 0;
    		uint naDays = (patient.daysCompleted - weekly_days) + 1; // excluding non required days
    		for (uint index = naDays; index <= patient.daysCompleted; index++) {
    			totalSteps = totalSteps + patient.footsteps[index].steps; // total steps in last 7 consecutive days
    		}
    		patient.avg_fs_week = (totalSteps / weekly_days); // storing average foot steps
    		if( patient.avg_fs_week < avg_fs_week_th ) { // validating eligibility criteria of patient's incentive
    			patient.ifEligible = false;
    		}
    	}
    	if(patient.daysCompleted == 30) {
    		patient.avg_fs_month = (patient.total_fs / 30); // storing monthly average footsteps
    	}
		emit footStepsRecorded(patient.id, true);
    	return true;
    }

    // to fetch the footsteps for a given patient at a given day
    function getFootsteps(uint patientId, uint day) external view validPatient(patientId) validDay(day) returns (uint steps, uint time) {
    	Patient storage patient = patients[patientId];
    	Footstep storage footstep = patient.footsteps[day];
    	return (
    		footstep.steps,
    		footstep.time
    	);
    }

    // to fetch the patient basic details from contract
    function getPatientDetails(uint patientId) external view validPatient(patientId)
        returns (uint _id, string memory _disease, uint _age, string memory _gender, bool ifEligible, uint daysCompleted) {
    	Patient memory patient = patients[patientId];
    	return (
			patient.id,
    		patient.disease,
    		patient.age,
    		patient.gender,
    		patient.ifEligible,
			patient.daysCompleted
    	);
    }

    // to settle the incentive or penalty at the end of month based on contract agreement b/w insurance provider & patient
    function settleRewards(uint patientId) external payable validPatient(patientId) onlyProvider returns (bool success) {
    	uint incentive = 0 ether;
		uint penalty = 4 ether;
		require(penalty <= address(this).balance, "Not enough balance available!");
    	Patient storage patient = patients[patientId];
    	require(patient.daysCompleted == monthly_days, "Month is not yet completed"); // settlement only when month ends
		// setting incentive as per eligibility criteria
    	if(patient.ifEligible) {
    		if(patient.avg_fs_month < 10000) {
    			incentive = 5 ether;
    		} else if(patient.avg_fs_month < 20000) {
    			incentive = 10 ether;
    		} else {
    			incentive = 20 ether;
    		}
    		require(msg.value >= incentive, "Insurance provider has insufficient balance to settleRewards");
			uint totalAmount = penalty + incentive;
    		patient.patientWallet.transfer(totalAmount); // transfer ether to patient wallet
			emit transactionCompleted(provider.providerWallet, true);
    	} else {
			uint totalAmount = penalty + msg.value;
    		provider.providerWallet.transfer(totalAmount); // transfer all ether back to provider including penalty
    		patient.walletAmount = 0 ether;
			emit transactionCompleted(patient.patientWallet, true);
    	}
    	delete patient.footsteps[patientId]; // reset steps for next coming month
		patient.daysCompleted = 0; // reset days for upcoming month
    	patient.ifEligible = true; // reset eligibility for next month
    	return true;
    }

}
