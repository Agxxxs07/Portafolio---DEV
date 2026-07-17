import kotlin.system.exitProcess // Esto es para poder cerrar el programa cuando el usuario elija salir

data class Pasajero(
    val nombre: String,
    val apellido: String,
    val edad: Int,
    val genero: String
)
data class Venta(
    val cliente: String,
    val edad: Int,
    val genero: String,
    val metodoPago: String,
    val total: Double,
    val descuento: Double
)

fun main() {
    // Lista donde vamos guardando todos los pasajeros que se registren
    val listaPasajeros = mutableListOf<Pasajero>()
    // Historial donde vamos guardando todos los boletos que se vendan
    val historialVentas = mutableListOf<Venta>()
    // Precio fijo del boleto
    val precioBase = 20.0

    // Este while hace que el menú se repita siempre hasta que el usuario salga
    while (true) {
        println("\n===== MENÚ TRANSPORTE =====")
        println("1. Registrar pasajero")
        println("2. Comprar boleto")
        println("3. Ver pasajeros registrados")
        println("4. Ver historial de ventas")
        println("5. Salir")
        print("Elija una opción: ")

        when (readln().toIntOrNull()) {

            1 -> {
                // ===== VALIDAR NOMBRE =====
                var nombre: String
                while (true) {
                    print("Ingrese nombre: ")
                    nombre = readln().trim()

                    // Solo letras (mayúsculas/minúsculas) y espacios
                    if (!nombre.matches(Regex("^[a-zA-ZáéíóúÁÉÍÓÚñÑ ]+$"))) {
                        println("El nombre solo debe contener letras")
                    } else if (nombre.isEmpty()) {
                        println("El nombre no puede estar vacío")
                    } else {
                        break
                    }
                }

                // ===== VALIDAR APELLIDO =====
                var apellido: String
                while (true) {
                    print("Ingrese apellido: ")
                    apellido = readln().trim()

                    if (!apellido.matches(Regex("^[a-zA-ZáéíóúÁÉÍÓÚñÑ ]+$"))) {
                        println("El apellido solo debe contener letras")
                    } else if (apellido.isEmpty()) {
                        println("El apellido no puede estar vacío")
                    } else {
                        break
                    }
                }

                // ===== VALIDAR EDAD =====
                var edad: Int
                while (true) {
                    print("Ingrese edad: ")
                    val entrada = readln().toIntOrNull()
                    // Aquí validamos que la edad sea válida (nada de negativos ni letras)
                    if (entrada == null || entrada < 0 || entrada > 120) {
                        println("Edad inválida (debe estar entre 0 y 120)")
                    } else {
                        edad = entrada
                        break
                    }
                }

                // ===== VALIDAR GÉNERO =====
                var genero: String
                while (true) {
                    print("Ingrese género (M/F): ")
                    genero = readln().uppercase().trim()

                    if (genero != "M" && genero != "F") {
                        println("Solo se permite M o F")
                    } else break
                }

                // Creamos el pasajero con los datos ingresados y lo guardamos en la lista
                val pasajero = Pasajero(nombre, apellido, edad, genero)
                listaPasajeros.add(pasajero)

                println("Pasajero guardado correctamente")
            }

            2 -> {
                // Si no hay pasajeros, no se puede comprar
                if (listaPasajeros.isEmpty()) {
                    println("Primero debes registrar al menos un pasajero")
                    continue
                }

                println("\nSeleccione un pasajero:")
                listaPasajeros.forEachIndexed { index, p ->
                    println("${index + 1}. ${p.nombre} ${p.apellido}")
                }

                var opcion: Int
                while (true) {
                    print("Ingrese una opción: ")
                    val entrada = readln().toIntOrNull()

                    if (entrada == null || entrada !in 1..listaPasajeros.size) {
                        println("Opción inválida, intenta otra vez")
                    } else {
                        opcion = entrada
                        break
                    }
                }

                val pasajero = listaPasajeros[opcion - 1]
                val nombreCompleto = "${pasajero.nombre} ${pasajero.apellido}"

                var descuento = 0.0

                // Aquí aplicamos las reglas del descuento
                if (pasajero.edad < 12) {
                    descuento = 0.05
                } else if (
                    (pasajero.genero == "F" && pasajero.edad > 57) ||
                    (pasajero.genero == "M" && pasajero.edad > 62)
                ) {
                    descuento = 0.15
                }

                // Calculamos el total a pagar
                val total = precioBase - (precioBase * descuento)

                println("\nTipo de pago:")
                println("1. Visa")
                println("2. Clave")
                println("3. Cheque")
                println("4. Efectivo")
                println("5. Transferencia")
                println("6. Yappy")

                var tipoPago: String
                while (true) {
                    print("Seleccione un método de pago: ")
                    tipoPago = when (readln().toIntOrNull()) {
                        1 -> "Visa"
                        2 -> "Clave"
                        3 -> "Cheque"
                        4 -> "Efectivo"
                        5 -> "Transferencia"
                        6 -> "Yappy"
                        else -> ""
                    }

                    if (tipoPago.isEmpty()) {
                        println("Selecciona un método válido")
                    } else break
                }

                // ===== GUARDAR VENTA =====
                val venta = Venta(
                    cliente = nombreCompleto,
                    edad = pasajero.edad,
                    genero = pasajero.genero,
                    metodoPago = tipoPago,
                    total = total,
                    descuento = descuento
                )
                historialVentas.add(venta)

                println("\n--- TRANSPORTE UTP S.A. -----")
                println("RUC: 01-2531-4507")
                println("\nTERMINAL PRINCIPAL\n")

                println("CLIENTE: $nombreCompleto")
                println("EDAD: ${pasajero.edad}")
                println("GENERO: ${pasajero.genero}")
                println("PAGO: $tipoPago")

                // Mostramos si tuvo descuento o no
                if (descuento > 0) {
                    println("DESCUENTO: ${descuento * 100}%")
                } else {
                    println("DESCUENTO: No aplica")
                }

                println("COSTO: B/ %.2f".format(total))
                println("\nBUEN VIAJE!")
            }

            // ===== OPCIÓN 3: VER LISTA DE PASAJEROS =====
            3 -> {
                if (listaPasajeros.isEmpty()) {
                    println("No hay pasajeros todavía")
                } else {
                    println("\nPasajeros registrados:")
                    listaPasajeros.forEachIndexed { i, p ->
                        println("${i + 1}. ${p.nombre} ${p.apellido} - Edad: ${p.edad}")
                    }
                }
            }

            // ===== OPCIÓN 4: HISTORIAL DE VENTAS =====
            4 -> {
                if (historialVentas.isEmpty()) {
                    println("No hay ventas registradas")
                } else {
                    println("\n===== HISTORIAL DE VENTAS =====")
                    historialVentas.forEachIndexed { i, v ->
                        println("${i + 1}. Cliente: ${v.cliente}")
                        println("   Edad: ${v.edad} | Género: ${v.genero}")
                        println("   Pago: ${v.metodoPago}")
                        println("   Descuento: ${if (v.descuento > 0) "${v.descuento * 100}%" else "No aplica"}")
                        println("   Total: B/ %.2f".format(v.total))
                        println("-----------------------------------")
                    }
                }
            }

            // ===== OPCIÓN 5: SALIR =====
            5 -> {
                println("Gracias por usar el sistema")
                exitProcess(0)
            }

            else -> println("Opción inválida")
        }
    }
}