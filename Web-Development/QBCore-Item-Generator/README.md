# QBCore Item List Generator

This project is a web-based application designed to simplify the creation and management of item lists for the QBCore framework used in FiveM servers. The application allows users to add items manually via a form or bulk import items using a CSV file. It also supports specific fields for weapon items, such as `ammoType`.

## Features

- **Manual Item Addition:** Add items one by one using an intuitive form.
- **CSV Bulk Import:** Upload a CSV file to quickly import multiple items.
- **Weapon Support:** Specify an `ammoType` for weapon items.
- **Code Generation:** Automatically generates Lua code for QBCore item definitions.
- **Copy to Clipboard:** Easily copy the generated code for use in your server.
- **Undo and Clear Options:** Remove the last added item or clear all items with a single click.

## Getting Started

Follow these instructions to set up and run the application locally.

### Prerequisites

- A modern web browser (Chrome, Firefox, Edge, Safari)

### Installation

1. **Clone the Repository:**

   ```bash
   git clone https://github.com/yourusername/qbcore-item-generator.git
   cd qbcore-item-generator
Open the Application:

Open the index.html file in your web browser.

Usage
Manual Item Addition
Enter Item Details:

Fill in the fields for item name, label, weight, type, image, unique, usable, close inventory, and description.
If the item is a weapon, specify the ammoType.
Add the Item:

Click "Add Item" to add the item to the list.
Bulk Import with CSV
Prepare the CSV File:

Use the following template to create your CSV file:
Item Name	Label	Weight (grams)	Type	Image	Unique	Usable	Close Inventory	Description	Ammo Type
water_bottle	Water	500	item	water.png	FALSE	TRUE	TRUE	A bottle of water.	
bread	Bread	200	item	bread.png	FALSE	TRUE	FALSE	A loaf of bread.	
pistol	Pistol	1000	weapon	pistol.png	FALSE	TRUE	TRUE	A standard pistol.	ammo_9mm
Save the CSV file with the necessary items.

Example file with the project.

Upload the CSV File:
Click "Choose File" and select your CSV file.

The items will be imported and displayed in the list.
Copy and Manage Items
Copy Code: Click "Copy" to copy the generated Lua code for all items to your clipboard.
Undo Last Item: Click "Undo" to remove the last added item from the list.
Clear List: Click "Clear List" to remove all items from the list.


CSV Format Details
Item Name: Unique identifier for the item.
Label: Display name for the item.
Weight (grams): The weight of the item in grams.
Type: The type of the item (item or weapon).
Image: File name of the item's image.
Unique: Whether the item is unique (TRUE or FALSE).
Usable: Whether the item can be used (TRUE or FALSE).
Close Inventory: Whether the inventory should close upon using the item (TRUE or FALSE).
Description: A brief description of the item.
Ammo Type: The type of ammunition used for weapons. Leave blank for non-weapon items.
Contributing
Contributions are welcome! Please feel free to submit a pull request or open an issue to contribute to this project.

License
This project is licensed under the MIT License. See the LICENSE file for details.

Acknowledgments
Special thanks to the QBCore community for their ongoing support and contributions to the FiveM community.
