-- CONFIG AUTOESCOLA (Syn Network) — usado para povoar o GlobalState

AutoSchool = {}

-- Categorias (veículo da prática por categoria)
AutoSchool.Categories = {
    { id = "A", label = "Mota (A)",      price = 2000,  group = "LicenseA", vehicle = "diablous" },
    { id = "B", label = "Carro (B)",     price = 5000,  group = "LicenseB", vehicle = "blista"   },
    { id = "C", label = "Autocarro (C)", price = 8000,  group = "LicenseC", vehicle = "rentalbus"},
    { id = "D", label = "Camião (D)",    price = 12000, group = "LicenseD", vehicle = "hauler"   }
}

-- Pontuação mínima (%)
AutoSchool.PassThreshold = 70

-- Perguntas (Sim/Não)
AutoSchool.Questions = {
    { q = "Deve usar o pisca ao mudar de faixa de rodagem?", correct = "Sim" },
    { q = "É permitido usar o telemóvel sem mãos-livres enquanto conduz?", correct = "Não" },
    { q = "Num cruzamento sem sinalização, deve ceder a passagem a quem vem da direita?", correct = "Sim" },
    { q = "Conduzir com álcool acima do limite legal é permitido de madrugada?", correct = "Não" },
    { q = "Deve ajustar a velocidade às condições meteorológicas adversas?", correct = "Sim" },
    { q = "Pode estacionar em lugares reservados a pessoas com deficiência sem dístico?", correct = "Não" },
    { q = "É obrigatório usar cinto de segurança em todos os lugares com cinto?", correct = "Sim" },
    { q = "Ultrapassar pela direita em via com duas ou mais vias no mesmo sentido é sempre permitido?", correct = "Não" },
    { q = "A distância de segurança deve aumentar com a chuva?", correct = "Sim" },
    { q = "É permitido parar/estacionar em cima do passeio?", correct = "Não" }
}

-- Posição do NPC e spawn do veículo de prática
AutoSchool.NPC          = vec4(240.99, -1379.07, 33.74, 138.76)
AutoSchool.SpawnVehicle = vec4(230.38, -1398.75, 30.49, 141.97)

-- Rota prática (igual para todas as categorias)
AutoSchool.Route = {
    { pos = vec3(218.16, -1410.82, 29), msg = "Pare e veja se vem alguém, após, siga à direita." },
    { pos = vec3(183.85, -1394.46, 29), msg = "Pare no semáforo." },
    { pos = vec3(221.60, -1327.54, 29), msg = "Continue para a direita e mude para a faixa do meio." },
    { pos = vec3(323.88, -1321.67, 31.60), msg = "Pare no semáforo e siga em frente." },
    { pos = vec3(431.64, -1420.47, 29), msg = "Pare no semáforo e siga para a direita." },
    { pos = vec3(336.86, -1493.80, 29), msg = "Pare no semáforo e siga pela direita." },
    { pos = vec3(259.66, -1448.58, 29), msg = "Pare no semáforo, e siga em frente." },
    { pos = vec3(223.64, -1412.19, 29), msg = "Chegámos, agora vá estacionar!" },
    { pos = vec3(240.89, -1393.99, 30.49), msg = "Sucesso!" }
}

-- Publica a config no GlobalState ao iniciar o recurso
AddEventHandler("onResourceStart", function(res)
    if GetCurrentResourceName() ~= res then return end
    GlobalState["AutoSchool:Categories"] = AutoSchool.Categories
    GlobalState["AutoSchool:Questions"]  = AutoSchool.Questions
    GlobalState["AutoSchool:Pass"]       = AutoSchool.PassThreshold or 70
    GlobalState["AutoSchool:Route"]      = AutoSchool.Route
    GlobalState["AutoSchool:NPC"]        = AutoSchool.NPC
    GlobalState["AutoSchool:Spawn"]      = AutoSchool.SpawnVehicle
end)
