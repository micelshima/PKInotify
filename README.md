# PKInotify
I created a pair of powershell scripts to keep track of certificate expiration and CRL expiration in a PKI.

pkinotifyGUI will show a form to fill in with your infrastructure settings:

    CA names an servernames
    path of the CLR distribution
    certificate templates to check
    smtp settings and warning threshold for sending the emails 

pkinotifyCLI will connect to the CDP and CAs given in the form and fill a SQLite database with the CRL's and certificates info.

The idea is to schedule pkinotifyCLI once of twice per week and manually execute pkinotifiyGUI to manipulate all the information.

Then you can exclude the certificates which are not in production (in use) and add granular email notifications if needed

GUI USAGE

    Single clicking an item will copy the information on the textboxes above so you can copy the text somewhere else.
    Double clicking an item in the listboxes will delete the selected item. It will also copy the information on the textboxes above in case you want to modify and insert the item again in the database.
    Orange "tick" button will insert the info in the textboxes in the database
    Certificate items will be shown in gray if they are disabled (in use = false) and yellow if the remaining expiration days are less than CER warning in settings tab.
    Form will display in red if a CRL or CER is in Warning. 
