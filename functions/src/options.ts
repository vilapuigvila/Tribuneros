import {setGlobalOptions} from "firebase-functions";

// Imported first by every module that defines a function: options set later don't apply to functions already defined.
setGlobalOptions({region: "europe-west1", maxInstances: 10});
