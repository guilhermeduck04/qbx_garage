let selectedVehicle = null;
let vehicleData = []; // Armazena a lista de veículos recebida
let selectedIndex = -1; // Rastreia o índice do veículo selecionado

// Listener para fechar com a tecla ESC
window.addEventListener('keyup', function(event) {
    if (event.key === 'Escape') {
        closeMenu();
    }
});

// Listener para navegação com as setas
window.addEventListener('keydown', function(event) {
    // Só executa se a garagem estiver visível
    if (document.getElementById('garage-container').style.display === 'none' || vehicleData.length === 0) {
        return;
    }

    let newIndex = selectedIndex;

    if (event.key === 'ArrowRight') {
        newIndex++;
        if (newIndex >= vehicleData.length) {
            newIndex = 0; // Volta para o início
        }
    } else if (event.key === 'ArrowLeft') {
        newIndex--;
        if (newIndex < 0) {
            newIndex = vehicleData.length - 1; // Vai para o final
        }
    }

    // Se o índice mudou, seleciona o novo veículo
    if (newIndex !== selectedIndex) {
        const vehicleElements = document.querySelectorAll('.vehicle-item');
        selectVehicle(vehicleData[newIndex], vehicleElements[newIndex], newIndex);
    }
});


// Listener para receber dados do LUA
window.addEventListener('message', function(event) {
    let data = event.data;
    if (data.action === 'open') {
        document.getElementById('garage-container').style.display = 'block';
        document.getElementById('vehicle-selection-bar').style.display = 'block';
        
        vehicleData = data.vehicles; // Armazena os dados dos veículos
        populateVehicleList(vehicleData);

        // Pré-seleciona o primeiro veículo da lista, se houver algum
        if (vehicleData.length > 0) {
            const firstVehicleElement = document.querySelector('.vehicle-item');
            selectVehicle(vehicleData[0], firstVehicleElement, 0);
        }
    }
});

function populateVehicleList(vehicles) {
    const vehicleList = document.getElementById('vehicle-list');
    vehicleList.innerHTML = '';
    vehicles.sort((a, b) => a.state - b.state);
    
    vehicles.forEach((vehicle, index) => { // Adicionado 'index' para o rastreamento
        const item = document.createElement('div');
        item.className = 'vehicle-item';
        
        const name = document.createElement('div');
        name.className = 'vehicle-name';
        name.textContent = `${vehicle.brand} ${vehicle.name}`;
        
        const plate = document.createElement('div');
        plate.className = 'vehicle-plate';
        plate.textContent = vehicle.props.plate;

        if (vehicle.state === 0) {
            const outIndicator = document.createElement('span');
            outIndicator.className = 'out-indicator';
            outIndicator.textContent = 'FORA';
            name.appendChild(outIndicator);
        }
        
        item.appendChild(name);
        item.appendChild(plate);

        item.onclick = () => selectVehicle(vehicle, item, index); // Passa o índice ao clicar
        vehicleList.appendChild(item);
    });
}

function selectVehicle(vehicle, element, index) { // Adicionado 'index'
    selectedVehicle = vehicle;
    selectedIndex = index; // Atualiza o índice global

    // Mostra o painel de informações
    document.querySelector('.vehicle-info-container').style.display = 'flex';

    document.querySelectorAll('.vehicle-item').forEach(el => el.classList.remove('selected'));
    element.classList.add('selected');

    // ##### ALTERAÇÃO PRINCIPAL AQUI #####
    // O comportamento agora é 'instant' para um acompanhamento perfeito.
    element.scrollIntoView({ behavior: 'instant', block: 'nearest', inline: 'center' });

    document.getElementById('vehicle-name').textContent = `${vehicle.brand} ${vehicle.name}`;
    document.getElementById('vehicle-plate').textContent = vehicle.props.plate;

    const enginePercent = Math.round(vehicle.props.engineHealth / 10);
    const bodyPercent = Math.round(vehicle.props.bodyHealth / 10);
    const fuelPercent = Math.round(vehicle.props.fuelLevel);

    updateStatusBar('engine', enginePercent);
    updateStatusBar('body', bodyPercent);
    updateStatusBar('fuel', fuelPercent);

    const takeOutBtn = document.getElementById('take-out-button');
    takeOutBtn.disabled = vehicle.state === 0;

    fetch(`https://${GetParentResourceName()}/previewVehicle`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ model: vehicle.modelName })
    });
}

function updateStatusBar(type, percent) {
    const text = document.getElementById(`vehicle-${type}-text`);
    const fill = document.getElementById(`vehicle-${type}-fill`);
    
    text.textContent = `${percent}%`;
    fill.style.width = `${percent}%`;
    fill.style.backgroundColor = getStatusColor(percent);
}

function getStatusColor(percent) {
    if (percent > 70) return '#34C759';
    if (percent > 30) return '#FFCC00';
    return '#FF3B30';
}

document.getElementById('take-out-button').addEventListener('click', () => {
    if (selectedVehicle) {
        fetch(`https://${GetParentResourceName()}/takeOutVehicle`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({ vehicle: selectedVehicle })
        });
        closeMenu();
    }
});

document.getElementById('park-nearby-button').addEventListener('click', () => {
    fetch(`https://${GetParentResourceName()}/parkNearbyVehicle`, { method: 'POST' });
});

document.getElementById('close-button').addEventListener('click', () => closeMenu());

function closeMenu() {
    if (document.getElementById('garage-container').style.display === 'none') return;
    
    document.getElementById('garage-container').style.display = 'none';
    document.getElementById('vehicle-selection-bar').style.display = 'none';
    
    fetch(`https://${GetParentResourceName()}/closeMenu`, { method: 'POST' });
    
    selectedVehicle = null;
    selectedIndex = -1;
    vehicleData = [];
    document.querySelector('.vehicle-info-container').style.display = 'none';
    document.getElementById('take-out-button').disabled = true;
}