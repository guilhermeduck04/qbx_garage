let selectedVehicle = null;

// Listener para fechar com a tecla ESC
window.addEventListener('keyup', function(event) {
    if (event.key === 'Escape') {
        closeMenu();
    }
});

// Listener para receber dados do LUA
window.addEventListener('message', function(event) {
    let data = event.data;
    if (data.action === 'open') {
        document.getElementById('garage-container').style.display = 'flex';
        populateVehicleList(data.vehicles);
    }
    // Adicionado para o LUA poder forçar o fecho e reabertura
    if (data.action === 'closeAndReopen') {
        closeMenu(false); // Fecha a UI sem notificar o LUA de volta
        // O LUA irá tratar de reenviar a ação 'open' com a lista atualizada
    }
});

function populateVehicleList(vehicles) {
    const vehicleList = document.getElementById('vehicle-list');
    vehicleList.innerHTML = '';
    // Veículos fora (state 0) primeiro na lista
    vehicles.sort((a, b) => a.state - b.state);
    
    vehicles.forEach(vehicle => {
        const item = document.createElement('div');
        item.className = 'vehicle-item';
        // Adiciona um indicador visual se o veículo está fora
        item.innerHTML = `${vehicle.brand} ${vehicle.name} ${vehicle.state === 0 ? '<span class="out-indicator">FORA</span>' : ''}`;
        item.onclick = () => selectVehicle(vehicle, item);
        vehicleList.appendChild(item);
    });
}

function selectVehicle(vehicle, element) {
    selectedVehicle = vehicle;

    document.querySelectorAll('.vehicle-item').forEach(el => el.classList.remove('selected'));
    element.classList.add('selected');

    document.getElementById('vehicle-name').textContent = `${vehicle.brand} ${vehicle.name}`;
    document.getElementById('vehicle-plate').textContent = vehicle.props.plate;

    const enginePercent = Math.round(vehicle.props.engineHealth / 10);
    const bodyPercent = Math.round(vehicle.props.bodyHealth / 10);
    const fuelPercent = Math.round(vehicle.props.fuelLevel);

    document.getElementById('vehicle-engine-text').textContent = `${enginePercent}%`;
    document.getElementById('vehicle-body-text').textContent = `${bodyPercent}%`;
    document.getElementById('vehicle-fuel-text').textContent = `${fuelPercent}%`;

    const engineFill = document.getElementById('vehicle-engine-fill');
    const bodyFill = document.getElementById('vehicle-body-fill');
    const fuelFill = document.getElementById('vehicle-fuel-fill');

    engineFill.style.width = `${enginePercent}%`;
    bodyFill.style.width = `${bodyPercent}%`;
    fuelFill.style.width = `${fuelPercent}%`;
    
    engineFill.style.backgroundColor = getStatusColor(enginePercent);
    bodyFill.style.backgroundColor = getStatusColor(bodyPercent);
    fuelFill.style.backgroundColor = getStatusColor(fuelPercent);

    // Lógica para habilitar/desabilitar botões
    const takeOutBtn = document.getElementById('take-out-button');
    const parkSelectedBtn = document.getElementById('park-selected-button');

    if (vehicle.state === 0) { // Veículo está FORA
        takeOutBtn.disabled = true;
        parkSelectedBtn.disabled = false;
    } else { // Veículo está GUARDADO
        takeOutBtn.disabled = false;
        parkSelectedBtn.disabled = true;
    }

    // Envia o modelo para o holograma
    fetch(`https://${GetParentResourceName()}/previewVehicle`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ model: vehicle.modelName })
    });
}

function getStatusColor(percent) {
    if (percent > 70) return '#34C759'; // Verde
    if (percent > 30) return '#FFCC00'; // Amarelo
    return '#FF3B30'; // Vermelho
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

document.getElementById('park-selected-button').addEventListener('click', () => {
    if (selectedVehicle) {
        fetch(`https://${GetParentResourceName()}/parkSelectedVehicle`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({ plate: selectedVehicle.props.plate })
        });
        // A lógica de reabrir o menu é tratada no LUA agora
    }
});

document.getElementById('close-button').addEventListener('click', () => closeMenu());

// Função de fecho modificada para evitar callbacks desnecessários
function closeMenu(notifyLua = true) {
    if (document.getElementById('garage-container').style.display === 'none') return;
    
    document.getElementById('garage-container').style.display = 'none';
    
    if (notifyLua) {
        fetch(`https://${GetParentResourceName()}/closeMenu`, { method: 'POST' });
    }
    
    // Reseta o painel para um estado limpo
    selectedVehicle = null;
    document.querySelectorAll('.vehicle-item').forEach(el => el.classList.remove('selected'));
    document.getElementById('take-out-button').disabled = true;
    document.getElementById('park-selected-button').disabled = true;
    document.getElementById('vehicle-name').textContent = 'Selecione um Veículo';
    document.getElementById('vehicle-plate').textContent = 'N/A';
    
    ['engine', 'body', 'fuel'].forEach(type => {
        document.getElementById(`vehicle-${type}-text`).textContent = `0%`;
        const fill = document.getElementById(`vehicle-${type}-fill`);
        fill.style.width = `0%`;
        fill.style.backgroundColor = getStatusColor(0);
    });
}