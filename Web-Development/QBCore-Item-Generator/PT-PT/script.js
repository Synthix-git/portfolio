let items = [];

// Function to add an item to the list
function addItem() {
    const name = document.getElementById('name').value.trim();
    const label = document.getElementById('label').value.trim();
    const weight = parseInt(document.getElementById('weight').value.trim(), 10);
    const type = document.getElementById('type').value.trim();
    const image = document.getElementById('image').value.trim();
    const unique = document.getElementById('unique').checked;
    const useable = document.getElementById('useable').checked;
    const shouldClose = document.getElementById('shouldClose').checked;
    const description = document.getElementById('description').value.trim();
    const ammoType = type === 'weapon' ? document.getElementById('ammoType').value.trim() : null;

    // Check if all required fields are filled
    if (!name || !label || isNaN(weight) || !type || !image || !description || (type === 'weapon' && !ammoType)) {
        alert("Por favor, preencha todos os campos.");
        return;
    }

    const item = {
        name,
        label,
        weight,
        type,
        ammoType,
        image,
        unique,
        useable,
        shouldClose,
        description
    };

    items.push(item);
    displayItems();
    clearForm();
}

// Function to display the list of items and generate Lua code
function displayItems() {
    const itemList = document.getElementById('itemList');
    const output = document.getElementById('output');
    itemList.innerHTML = '';
    output.innerHTML = '';

    items.forEach((item, index) => {
        const itemElement = document.createElement('div');
        itemElement.classList.add('item');
        itemElement.textContent = `${index + 1}. ${item.label} (${item.name})`;
        itemList.appendChild(itemElement);

        // Generate Lua code for each item
        let itemCode = `
['${item.name}'] = {
    name = '${item.name}',
    label = '${item.label}',
    weight = ${item.weight},
    type = '${item.type}',
    image = '${item.image}',
    unique = ${item.unique},
    useable = ${item.useable},
    shouldClose = ${item.shouldClose},
    combinable = nil,
    description = '${item.description}'
`;

        // Add ammoType only if it's a weapon with a specified ammoType
        if (item.type === 'weapon' && item.ammoType) {
            itemCode += `,\n    ammoType = '${item.ammoType}'`;
        }

        itemCode += '\n},\n';

        output.textContent += itemCode;
    });
}

// Function to clear the form
function clearForm() {
    document.getElementById('itemForm').reset();
    toggleAmmoType(); // Reset ammoType visibility
}

// Function to clear all items
function clearItems() {
    items = [];
    displayItems();
}

// Function to remove the last item
function cancelLastItem() {
    if (items.length > 0) {
        items.pop();
        displayItems();
    } else {
        alert("Não há itens para anular.");
    }
}

// Function to copy the generated code to the clipboard
function copyToClipboard() {
    const output = document.getElementById('output');
    const textarea = document.createElement('textarea');
    textarea.value = output.textContent;
    document.body.appendChild(textarea);
    textarea.select();
    document.execCommand('copy');
    document.body.removeChild(textarea);
    alert("Código copiado para a área de transferência!");
}

// Function to load and parse CSV file
function loadCSVFile(event) {
    const file = event.target.files[0];
    if (!file) {
        alert("Nenhum ficheiro selecionado.");
        return;
    }

    const reader = new FileReader();
    reader.onload = function(e) {
        const csvContent = e.target.result;
        parseCSV(csvContent);
    };
    reader.readAsText(file);
}

// Function to parse CSV content and add items
function parseCSV(csvContent) {
    const lines = csvContent.split('\n');
    const headers = lines[0].split(',').map(header => header.trim().toLowerCase());

    lines.slice(1).forEach(line => {
        const values = line.split(',').map(value => value.trim());
        if (values.length === headers.length && values[0]) { // Ensure line has correct number of columns
            const item = {};
            headers.forEach((header, index) => {
                item[header] = values[index];
            });

            // Convert boolean strings to actual booleans
            item.unique = item['único'].toLowerCase() === 'true';
            item.useable = item['usável'].toLowerCase() === 'true';
            item.shouldclose = item['fechar inventário'].toLowerCase() === 'true';

            // Parse integers
            item.weight = parseInt(item['peso (gramas)'], 10);

            // Ensure item fields are correctly populated
            if (item['nome do item'] && item['etiqueta'] && !isNaN(item.weight) && item['tipo'] && item['imagem'] && item['descrição']) {
                items.push({
                    name: item['nome do item'],
                    label: item['etiqueta'],
                    weight: item['peso (gramas)'],
                    type: item['tipo'],
                    ammoType: item['tipo'] === 'weapon' ? item['ammotype'] : null,
                    image: item['imagem'],
                    unique: item['único'],
                    useable: item['usável'],
                    shouldClose: item['fechar inventário'],
                    description: item['descrição']
                });
            }
        }
    });

    displayItems();
}

// Function to toggle ammoType input visibility
function toggleAmmoType() {
    const type = document.getElementById('type').value;
    const ammoTypeInput = document.getElementById('ammoType');
    if (type === 'weapon') {
        ammoTypeInput.classList.remove('hidden');
        ammoTypeInput.setAttribute('required', 'required');
    } else {
        ammoTypeInput.classList.add('hidden');
        ammoTypeInput.removeAttribute('required');
    }
}
