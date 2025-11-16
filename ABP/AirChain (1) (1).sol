// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title AirChain - Sistema IoT basado en blockchain para monitoreo de calidad de aire
 * @dev Contrato inteligente para registrar dispositivos IoT y almacenar lecturas ambientales
 * @author Fernando Gimenez Coria, Raul Jara, Diego Ares, Macarena Carballo
 */
contract AirChain {
    address public owner;
    
    /**
     * @dev Estructura para almacenar información de cada dispositivo IoT
     * @param id Identificador único del dispositivo
     * @param deviceOwner Dirección Ethereum del propietario del dispositivo
     * @param registered Estado de registro del dispositivo
     * @param registrationDate Fecha de registro en timestamp Unix
     */
    struct Device {
        string id;
        address deviceOwner;
        bool registered;
        uint256 registrationDate;
    }
    
    /**
     * @dev Estructura para almacenar lecturas ambientales de los sensores
     * @param timestamp Momento en que se tomó la lectura (timestamp Unix)
     * @param temperature Temperatura ambiental en grados Celsius
     * @param humidity Humedad relativa en porcentaje (0-100%)
     * @param pressure Presión atmosférica en Pascales (Pa)
     * @param co2 Concentración de CO2 en partes por millón (ppm)
     * @param pm25 Concentración de partículas PM2.5 en μg/m³
     * @param voc Compuestos orgánicos volátiles en partes por billón (ppb)
     */
    struct Reading {
        uint256 timestamp;
        int256 temperature; // Cambiado a int256 para permitir valores negativos
        uint256 humidity;
        uint256 pressure;
        uint256 co2;
        uint256 pm25;
        uint256 voc;
    }
    
    // Mappings principales para almacenamiento de datos
    mapping(string => Device) public devices;                    // Dispositivos por ID
    mapping(string => Reading) public lastReadings;             // Última lectura por dispositivo
    mapping(address => mapping(string => bool)) private _ownerDeviceIds; // Verificación rápida de ownership
    mapping(address => string[]) public ownerDevices;           // Lista de dispositivos por propietario
    
    // Array para tracking de todos los dispositivos registrados
    string[] public allDeviceIds;
    
    // Eventos para seguimiento y auditoría
    event DeviceRegistered(string deviceId, address owner);
    event ReadingUpdated(string deviceId, uint256 timestamp);
    event DeviceOwnershipTransferred(string deviceId, address previousOwner, address newOwner);
    event DeviceDeregistered(string deviceId, address by);

    /**
     * @dev Modificador: solo permite ejecución al owner del contrato
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Solo el owner del contrato");
        _;
    }
    
    /**
     * @dev Modificador: solo permite ejecución al propietario del dispositivo
     * @param deviceId ID del dispositivo a verificar
     */
    modifier onlyDeviceOwner(string memory deviceId) {
        require(devices[deviceId].registered, "Dispositivo no registrado");
        require(devices[deviceId].deviceOwner == msg.sender, "No eres el propietario");
        _;
    }

    /**
     * @dev Modificador: permite ejecución al propietario del dispositivo O al owner del contrato
     * @param deviceId ID del dispositivo a verificar
     */
    modifier onlyDeviceOwnerOrContractOwner(string memory deviceId) {
        require(devices[deviceId].registered, "Dispositivo no registrado");
        require(
            devices[deviceId].deviceOwner == msg.sender || msg.sender == owner,
            "No tienes permisos"
        );
        _;
    }
    
    /**
     * @dev Modificador: verifica que el dispositivo NO esté registrado
     * @param deviceId ID del dispositivo a verificar
     */
    modifier deviceNotRegistered(string memory deviceId) {
        require(!devices[deviceId].registered, "Dispositivo ya registrado");
        _;
    }

    /**
     * @dev Constructor: inicializa el contrato estableciendo al deployer como owner
     */
    constructor() {
        owner = msg.sender;
    }
    
    // ========== FUNCIONES PRINCIPALES ==========
    
    /**
     * @dev Registra un nuevo dispositivo IoT en el sistema
     * @param deviceId Identificador único del dispositivo a registrar
     * @notice El deviceId debe ser único y no estar vacío. Máximo 32 caracteres para prevenir spam.
     */
    function registerDevice(string memory deviceId) public deviceNotRegistered(deviceId) {
        require(bytes(deviceId).length > 0, "ID vacio");
        require(bytes(deviceId).length <= 32, "ID demasiado largo"); // Prevenir spam
        
        devices[deviceId] = Device({
            id: deviceId,
            deviceOwner: msg.sender,
            registered: true,
            registrationDate: block.timestamp
        });
        
        // Registrar en mappings optimizados para búsquedas rápidas
        _ownerDeviceIds[msg.sender][deviceId] = true;
        ownerDevices[msg.sender].push(deviceId);
        allDeviceIds.push(deviceId);
        
        emit DeviceRegistered(deviceId, msg.sender);
    }
    
    /**
     * @dev Actualiza las lecturas ambientales de un dispositivo
     * @param deviceId ID del dispositivo a actualizar
     * @param temperature Temperatura en °C (rango: -50 a 100)
     * @param humidity Humedad relativa en % (rango: 0-100)
     * @param pressure Presión atmosférica en Pa (rango: 30000-110000)
     * @param co2 Concentración CO2 en ppm (rango: 300-5000)
     * @param pm25 Partículas PM2.5 en μg/m³ (rango: 0-500)
     * @param voc Compuestos orgánicos volátiles en ppb (rango: 0-1000)
     * @notice Solo el propietario del dispositivo puede ejecutar esta función
     */
    function updateReading(
        string memory deviceId,
        int256 temperature, // Cambiado a int256 para permitir valores negativos
        uint256 humidity,
        uint256 pressure,
        uint256 co2,
        uint256 pm25,
        uint256 voc
    ) public onlyDeviceOwner(deviceId) {
        // VALIDACIONES DE RANGO PARA DATOS REALISTAS
        require(temperature >= -50 && temperature <= 100, "Temperatura invalida"); // -50°C a 100°C
        require(humidity >= 0 && humidity <= 100, "Humedad invalida"); // 0-100%
        require(pressure >= 30000 && pressure <= 110000, "Presion invalida"); // 300-1100 hPa (en Pa)
        require(co2 >= 300 && co2 <= 5000, "CO2 invalido"); // 300-5000 ppm
        require(pm25 >= 0 && pm25 <= 500, "PM2.5 invalido"); // 0-500 μg/m³
        require(voc >= 0 && voc <= 1000, "VOC invalido"); // 0-1000 ppb

        lastReadings[deviceId] = Reading({
            timestamp: block.timestamp,
            temperature: temperature,
            humidity: humidity,
            pressure: pressure,
            co2: co2,
            pm25: pm25,
            voc: voc
        });
        
        emit ReadingUpdated(deviceId, block.timestamp);
    }
    
    // ========== FUNCIONES DE ADMINISTRACIÓN ==========
    
    /**
     * @dev Da de baja un dispositivo del sistema
     * @param deviceId ID del dispositivo a eliminar
     * @notice Puede ser ejecutado por el propietario del dispositivo o el owner del contrato
     * @notice Los datos del dispositivo y sus lecturas se eliminan permanentemente
     */
    function deregisterDevice(string memory deviceId) public onlyDeviceOwnerOrContractOwner(deviceId) {
        require(devices[deviceId].registered, "Dispositivo no registrado");
        
        address deviceOwner = devices[deviceId].deviceOwner;
        
        // Limpiar todos los mappings y almacenamiento
        delete _ownerDeviceIds[deviceOwner][deviceId];
        delete devices[deviceId];
        delete lastReadings[deviceId];
        
        emit DeviceDeregistered(deviceId, msg.sender);
    }
    
    /**
     * @dev Transfiere la propiedad del contrato a una nueva dirección
     * @param newOwner Dirección del nuevo propietario del contrato
     * @notice Solo el owner actual puede ejecutar esta función
     */
    function transferContractOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Nuevo owner invalido");
        owner = newOwner;
    }
    
    // ========== FUNCIONES DE CONSULTA ==========
    
    /**
     * @dev Obtiene la última lectura registrada de un dispositivo
     * @param deviceId ID del dispositivo a consultar
     * @return Reading Estructura con todos los datos de la última lectura
     */
    function getLastReading(string memory deviceId) public view returns (Reading memory) {
        require(devices[deviceId].registered, "Dispositivo no registrado");
        return lastReadings[deviceId];
    }
    
    /**
     * @dev Obtiene la lista de todos los dispositivos registrados en el sistema
     * @return string[] Array con los IDs de todos los dispositivos
     */
    function getAllDevices() public view returns (string[] memory) {
        return allDeviceIds;
    }
    
    /**
     * @dev Obtiene los dispositivos registrados por un propietario específico
     * @param deviceOwner Dirección del propietario a consultar
     * @return string[] Array con los IDs de los dispositivos del propietario
     */
    function getDevicesByOwner(address deviceOwner) public view returns (string[] memory) {
        return ownerDevices[deviceOwner];
    }
    
    /**
     * @dev Obtiene los dispositivos del caller actual
     * @return string[] Array con los IDs de los dispositivos del msg.sender
     */
    function getMyDevices() public view returns (string[] memory) {
        return ownerDevices[msg.sender];
    }
    
    /**
     * @dev Verifica si un dispositivo está registrado en el sistema
     * @param deviceId ID del dispositivo a verificar
     * @return bool True si el dispositivo está registrado, false en caso contrario
     */
    function isDeviceRegistered(string memory deviceId) public view returns (bool) {
        return devices[deviceId].registered;
    }
    
    /**
     * @dev Obtiene información completa de un dispositivo
     * @param deviceId ID del dispositivo a consultar
     * @return Device Estructura con toda la información del dispositivo
     */
    function getDeviceInfo(string memory deviceId) public view returns (Device memory) {
        require(devices[deviceId].registered, "Dispositivo no registrado");
        return devices[deviceId];
    }
    
    /**
     * @dev Verificación rápida de ownership (operación O(1))
     * @param user Dirección del usuario a verificar
     * @param deviceId ID del dispositivo a verificar
     * @return bool True si el usuario es propietario del dispositivo
     */
    function isOwnerOfDevice(address user, string memory deviceId) public view returns (bool) {
        return _ownerDeviceIds[user][deviceId];
    }
    
    // ========== FUNCIONES DE TRANSFERENCIA ==========
    
    /**
     * @dev Transfiere la propiedad de un dispositivo a otro usuario
     * @param deviceId ID del dispositivo a transferir
     * @param newOwner Dirección del nuevo propietario
     * @notice Solo el propietario actual del dispositivo puede ejecutar esta función
     */
    function transferDeviceOwnership(string memory deviceId, address newOwner) public onlyDeviceOwner(deviceId) {
        require(newOwner != address(0), "Nuevo owner invalido");
        require(newOwner != msg.sender, "No puedes transferir a ti mismo");
        
        address previousOwner = devices[deviceId].deviceOwner;
        devices[deviceId].deviceOwner = newOwner;
        
        // Actualizar mappings optimizados
        delete _ownerDeviceIds[previousOwner][deviceId];
        _ownerDeviceIds[newOwner][deviceId] = true;
        
        // Agregar a la lista del nuevo propietario
        ownerDevices[newOwner].push(deviceId);
        
        emit DeviceOwnershipTransferred(deviceId, previousOwner, newOwner);
    }
    
    /**
     * @dev Obtiene el número total de dispositivos registrados en el sistema
     * @return uint256 Cantidad total de dispositivos registrados
     */
    function getTotalDevices() public view returns (uint256) {
        return allDeviceIds.length;
    }
}