# PKI Notify v2
I created a pair of powershell scripts to keep track of certificate expiration and CRL expiration in a PKI.

pkinotifyGUI will show a form to fill in with your infrastructure settings:

    CA names an servernames
    path of the CLR distribution
    certificate templates to check
    SMTP settings and warning threshold for sending the emails 

pkinotifyCLI will connect to the CDP and CAs given in the form and fill a SQLite database with the CRL's and certificates info.

The idea is to schedule pkinotifyCLI once of twice per week and manually execute pkinotifiyGUI to manipulate all the information.

Then you can exclude the certificates which are not in production (in use) and add granular email notifications if needed.
If you need to delete a registry just clear the name and it will be deleted.

![alt tag](https://1.bp.blogspot.com/-9wSx3_7wIgc/X550KmwfnhI/AAAAAAAACSE/WkOa9X5VSP0Uw0BtJva9sAlU0OMrFHB_ACLcBGAsYHQ/s1096/PKINotifyv2.gif)


