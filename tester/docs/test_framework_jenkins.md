## Integrating Jenkins with Bindle Test Framework Tutorial

This is our SOP on how one can integrate the Bindle Tester with Jenkins. This approach establishes continous integration for Bindle which can be very useful while it is undergoing development. Continous Integration is a development practise that requires developers to integrate code into a shared repository several times a day. Each check-in is then verified by an automated build. Currently, we are examining code changes only for the develop and release branches and also watching out for pull requests. 

### Use Cases
One use case for integrating Jenkins with Bindle Tester is to detect problems earlier and locate them easily since we know what code changes has caused this problem. Another use case is that it significantly reduces the time taken to manually test bindle. 

