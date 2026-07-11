using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;

public sealed class ChaosGunGame : MonoBehaviour
{
    public static readonly List<ChaosGunFighter> Fighters = new();

    private readonly Vector3[] _spawnPoints =
    {
        new(-8f, 1.2f, 0f),
        new(8f, 1.2f, 0f),
        new(-14f, 1.2f, -5f),
        new(14f, 1.2f, 5f)
    };

    private ChaosGunHud _hud;
    private float _pickupTimer;
    private bool _ended;
    private string _winner = "";

    public Vector3 RandomSpawn => _spawnPoints[Random.Range(0, _spawnPoints.Length)];
    public string Winner => _winner;

    private void Awake()
    {
        Fighters.Clear();
        Application.targetFrameRate = 120;
    }

    private void Start()
    {
        BuildCameraAndLight();
        BuildArena();
        CreateFighter("Player", true, _spawnPoints[0], new Color(0.1f, 0.45f, 1f));
        CreateFighter("AI Bot", false, _spawnPoints[1], new Color(1f, 0.22f, 0.12f));
        SpawnPickup(new Vector3(0f, 1.4f, -5f));
        SpawnPickup(new Vector3(-10f, 1.4f, 5f));
        SpawnPickup(new Vector3(10f, 1.4f, 5f));

        _hud = gameObject.AddComponent<ChaosGunHud>();
        _hud.Bind(this);
    }

    private void Update()
    {
        if (_ended)
        {
            if (Keyboard.current != null && Keyboard.current.rKey.wasPressedThisFrame)
            {
                UnityEngine.SceneManagement.SceneManager.LoadScene(
                    UnityEngine.SceneManagement.SceneManager.GetActiveScene().buildIndex);
            }
            return;
        }

        _pickupTimer -= Time.deltaTime;
        if (_pickupTimer <= 0f && FindObjectsByType<ChaosGunWeaponPickup>(FindObjectsSortMode.None).Length < 4)
        {
            _pickupTimer = 10f;
            SpawnPickup(new Vector3(Random.Range(-13f, 13f), 1.4f, Random.Range(-6f, 6f)));
        }

        int alive = 0;
        ChaosGunFighter survivor = null;
        foreach (var fighter in Fighters)
        {
            if (fighter != null && !fighter.GameOver)
            {
                alive++;
                survivor = fighter;
            }
        }

        if (alive <= 1)
        {
            _ended = true;
            _winner = survivor != null ? survivor.DisplayName : "DRAW";
        }
    }

    private static Material MakeMaterial(Color color, float metallic = 0f, float smoothness = 0.35f)
    {
        var mat = new Material(Shader.Find("Universal Render Pipeline/Lit"));
        mat.color = color;
        mat.SetFloat("_Metallic", metallic);
        mat.SetFloat("_Smoothness", smoothness);
        return mat;
    }

    private void BuildCameraAndLight()
    {
        var camObject = new GameObject("ChaosGun Camera");
        var cam = camObject.AddComponent<Camera>();
        cam.tag = "MainCamera";
        cam.orthographic = true;
        cam.orthographicSize = 13f;
        camObject.transform.SetPositionAndRotation(new Vector3(0f, 18f, -20f), Quaternion.Euler(58f, 0f, 0f));
        camObject.AddComponent<AudioListener>();

        var lightObject = new GameObject("Sun");
        var light = lightObject.AddComponent<Light>();
        light.type = LightType.Directional;
        light.intensity = 1.25f;
        lightObject.transform.rotation = Quaternion.Euler(48f, -25f, 0f);
    }

    private void BuildArena()
    {
        var floorMat = MakeMaterial(new Color(0.34f, 0.36f, 0.34f));
        var trimMat = MakeMaterial(new Color(0.9f, 0.68f, 0.22f));
        CreateCube("Main Platform", new Vector3(0f, -0.35f, 0f), new Vector3(34f, 0.7f, 18f), floorMat);
        CreateCube("Raised Left", new Vector3(-11f, 1.2f, -5.2f), new Vector3(9f, 0.6f, 4f), floorMat);
        CreateCube("Raised Right", new Vector3(11f, 1.2f, 5.2f), new Vector3(9f, 0.6f, 4f), floorMat);
        CreateCube("Center Cover", new Vector3(0f, 1.1f, 0f), new Vector3(2f, 2.2f, 2f), trimMat);
        CreateCube("Left Cover", new Vector3(-6f, 0.55f, 4f), new Vector3(2.4f, 1.1f, 1.6f), trimMat);
        CreateCube("Right Cover", new Vector3(6f, 0.55f, -4f), new Vector3(2.4f, 1.1f, 1.6f), trimMat);
    }

    private static GameObject CreateCube(string name, Vector3 position, Vector3 scale, Material mat)
    {
        var obj = GameObject.CreatePrimitive(PrimitiveType.Cube);
        obj.name = name;
        obj.transform.position = position;
        obj.transform.localScale = scale;
        obj.GetComponent<Renderer>().sharedMaterial = mat;
        return obj;
    }

    private ChaosGunFighter CreateFighter(string displayName, bool playerControlled, Vector3 position, Color color)
    {
        var root = new GameObject(displayName);
        root.transform.position = position;

        var rb = root.AddComponent<Rigidbody>();
        rb.mass = 1.2f;
        rb.freezeRotation = true;
        rb.collisionDetectionMode = CollisionDetectionMode.ContinuousDynamic;
#if UNITY_6000_0_OR_NEWER
        rb.linearDamping = 0.6f;
        rb.angularDamping = 8f;
#else
        rb.drag = 0.6f;
        rb.angularDrag = 8f;
#endif

        var collider = root.AddComponent<CapsuleCollider>();
        collider.height = 2f;
        collider.radius = 0.55f;
        collider.center = Vector3.up;

        var visual = GameObject.CreatePrimitive(PrimitiveType.Capsule);
        visual.name = "Visual";
        visual.transform.SetParent(root.transform, false);
        visual.transform.localPosition = Vector3.up;
        visual.GetComponent<Renderer>().sharedMaterial = MakeMaterial(color, 0f, 0.55f);
        Destroy(visual.GetComponent<Collider>());

        var weaponPoint = new GameObject("WeaponPoint");
        weaponPoint.transform.SetParent(root.transform, false);
        weaponPoint.transform.localPosition = new Vector3(0f, 1.1f, 0.85f);

        var fighter = root.AddComponent<ChaosGunFighter>();
        fighter.Configure(this, displayName, playerControlled, weaponPoint.transform);
        Fighters.Add(fighter);
        return fighter;
    }

    private void SpawnPickup(Vector3 position)
    {
        var obj = GameObject.CreatePrimitive(PrimitiveType.Cube);
        obj.name = "Weapon Pickup";
        obj.transform.position = position;
        obj.transform.localScale = new Vector3(0.9f, 0.35f, 1.25f);
        obj.GetComponent<Renderer>().sharedMaterial = MakeMaterial(new Color(1f, 0.85f, 0.12f), 0f, 0.75f);
        var collider = obj.GetComponent<BoxCollider>();
        collider.isTrigger = true;
        var pickup = obj.AddComponent<ChaosGunWeaponPickup>();
        pickup.weapon = ChaosGunWeapon.RandomPrimary();
    }
}

public enum ChaosGunFireMode
{
    SemiAuto,
    FullAuto,
    BoltAction
}

public sealed class ChaosGunWeapon
{
    public string Name;
    public ChaosGunFireMode FireMode;
    public float FireRate;
    public float BulletSpeed;
    public float Knockback;
    public float Damage;
    public float Recoil;
    public float Spread;
    public int MagazineSize;
    public int Ammo;
    public Color Color;

    public static ChaosGunWeapon Pistol() => new()
    {
        Name = "Pistol",
        FireMode = ChaosGunFireMode.SemiAuto,
        FireRate = 4f,
        BulletSpeed = 42f,
        Knockback = 16f,
        Damage = 25f,
        Recoil = 3.5f,
        Spread = 0f,
        MagazineSize = -1,
        Ammo = -1,
        Color = new Color(1f, 0.38f, 0.16f)
    };

    public static ChaosGunWeapon Smg() => new()
    {
        Name = "SMG",
        FireMode = ChaosGunFireMode.FullAuto,
        FireRate = 12f,
        BulletSpeed = 44f,
        Knockback = 9f,
        Damage = 12f,
        Recoil = 1.8f,
        Spread = 3f,
        MagazineSize = 40,
        Ammo = 40,
        Color = new Color(0.35f, 1f, 0.9f)
    };

    public static ChaosGunWeapon AkRifle() => new()
    {
        Name = "AK Rifle",
        FireMode = ChaosGunFireMode.FullAuto,
        FireRate = 6f,
        BulletSpeed = 52f,
        Knockback = 14f,
        Damage = 20f,
        Recoil = 4.5f,
        Spread = 2f,
        MagazineSize = 25,
        Ammo = 25,
        Color = new Color(1f, 0.62f, 0.2f)
    };

    public static ChaosGunWeapon Sniper() => new()
    {
        Name = "Sniper",
        FireMode = ChaosGunFireMode.BoltAction,
        FireRate = 0.8f,
        BulletSpeed = 72f,
        Knockback = 58f,
        Damage = 80f,
        Recoil = 10f,
        Spread = 0f,
        MagazineSize = 5,
        Ammo = 5,
        Color = new Color(1f, 0.15f, 0.1f)
    };

    public static ChaosGunWeapon RandomPrimary()
    {
        return Random.Range(0, 3) switch
        {
            0 => Smg(),
            1 => AkRifle(),
            _ => Sniper()
        };
    }
}

public sealed class ChaosGunFighter : MonoBehaviour
{
    public string DisplayName { get; private set; }
    public int Lives { get; private set; } = 10;
    public int Kills { get; private set; }
    public int Deaths { get; private set; }
    public float Hp { get; private set; } = 3000f;
    public bool GameOver => Lives <= 0;
    public bool IsDead { get; private set; }
    public ChaosGunWeapon CurrentWeapon => _weapon;

    private const float MaxHp = 3000f;
    private const float FallY = -12f;
    private const float MoveAcceleration = 72f;
    private const float AirControl = 0.22f;
    private const float JumpVelocity = 9.5f;

    private ChaosGunGame _game;
    private bool _playerControlled;
    private Transform _weaponPoint;
    private Rigidbody _rb;
    private Collider _collider;
    private Renderer[] _renderers;
    private ChaosGunWeapon _weapon = ChaosGunWeapon.Pistol();
    private ChaosGunFighter _lastHitBy;
    private float _fireCooldown;
    private float _respawnTimer;
    private float _invincibleTimer;
    private float _aiThinkTimer;
    private Vector3 _faceDir = Vector3.forward;

    public void Configure(ChaosGunGame game, string displayName, bool playerControlled, Transform weaponPoint)
    {
        _game = game;
        DisplayName = displayName;
        _playerControlled = playerControlled;
        _weaponPoint = weaponPoint;
    }

    private void Awake()
    {
        _rb = GetComponent<Rigidbody>();
        _collider = GetComponent<Collider>();
        _renderers = GetComponentsInChildren<Renderer>();
    }

    private void Update()
    {
        _fireCooldown -= Time.deltaTime;

        if (IsDead)
        {
            _respawnTimer -= Time.deltaTime;
            if (_respawnTimer <= 0f && !GameOver)
            {
                Respawn();
            }
            return;
        }

        if (transform.position.y < FallY)
        {
            Die();
            return;
        }

        if (_invincibleTimer > 0f)
        {
            _invincibleTimer -= Time.deltaTime;
            bool visible = Mathf.Repeat(_invincibleTimer, 0.24f) > 0.1f;
            SetRenderersVisible(visible);
            if (_invincibleTimer <= 0f)
            {
                SetRenderersVisible(true);
            }
        }

        if (_playerControlled)
        {
            HandlePlayerFire();
        }
        else
        {
            HandleAiFire();
        }
    }

    private void FixedUpdate()
    {
        if (IsDead || GameOver)
        {
            return;
        }

        Vector3 move = _playerControlled ? ReadPlayerMove() : ReadAiMove();
        float control = IsGrounded() ? 1f : AirControl;
        _rb.AddForce(move * MoveAcceleration * control, ForceMode.Acceleration);

        if (move.sqrMagnitude > 0.02f)
        {
            _faceDir = Vector3.Slerp(_faceDir, move.normalized, 0.25f);
        }

        if (_faceDir.sqrMagnitude > 0.01f)
        {
            transform.rotation = Quaternion.Slerp(transform.rotation, Quaternion.LookRotation(_faceDir), 0.28f);
        }
    }

    private Vector3 ReadPlayerMove()
    {
        var keyboard = Keyboard.current;
        if (keyboard == null)
        {
            return Vector3.zero;
        }

        Vector2 axis = Vector2.zero;
        if (keyboard.aKey.isPressed) axis.x -= 1f;
        if (keyboard.dKey.isPressed) axis.x += 1f;
        if (keyboard.sKey.isPressed) axis.y -= 1f;
        if (keyboard.wKey.isPressed) axis.y += 1f;

        if (keyboard.spaceKey.wasPressedThisFrame && IsGrounded())
        {
            var v = _rb.linearVelocity;
            v.y = JumpVelocity;
            _rb.linearVelocity = v;
        }

        if (keyboard.digit1Key.wasPressedThisFrame)
        {
            Equip(ChaosGunWeapon.Pistol());
        }

        return new Vector3(axis.x, 0f, axis.y).normalized;
    }

    private Vector3 ReadAiMove()
    {
        var target = FindTarget();
        if (target == null)
        {
            return Vector3.zero;
        }

        Vector3 toTarget = target.transform.position - transform.position;
        toTarget.y = 0f;
        float distance = toTarget.magnitude;
        if (distance < 8f)
        {
            return Vector3.zero;
        }

        Vector3 desired = toTarget.normalized;
        if (!HasGroundAhead(desired))
        {
            desired = -desired;
        }
        return desired;
    }

    private void HandlePlayerFire()
    {
        Vector3 aim = MouseAimDirection();
        if (aim.sqrMagnitude > 0.01f)
        {
            _faceDir = aim;
        }

        var mouse = Mouse.current;
        if (mouse == null)
        {
            return;
        }

        bool shouldFire = _weapon.FireMode == ChaosGunFireMode.FullAuto
            ? mouse.leftButton.isPressed
            : mouse.leftButton.wasPressedThisFrame;

        if (shouldFire)
        {
            TryFire(aim);
        }
    }

    private void HandleAiFire()
    {
        var target = FindTarget();
        if (target == null)
        {
            return;
        }

        Vector3 aim = target.transform.position + Vector3.up - _weaponPoint.position;
        if (aim.sqrMagnitude <= 0.01f)
        {
            return;
        }

        aim.Normalize();
        _faceDir = new Vector3(aim.x, 0f, aim.z).normalized;
        _aiThinkTimer -= Time.deltaTime;
        if (_aiThinkTimer <= 0f && Vector3.Distance(transform.position, target.transform.position) < 25f)
        {
            _aiThinkTimer = Random.Range(0.08f, 0.22f);
            TryFire(Quaternion.Euler(0f, Random.Range(-4f, 4f), 0f) * aim);
        }
    }

    private Vector3 MouseAimDirection()
    {
        var cam = Camera.main;
        var mouse = Mouse.current;
        if (cam == null || mouse == null)
        {
            return _faceDir;
        }

        Ray ray = cam.ScreenPointToRay(mouse.position.ReadValue());
        var plane = new Plane(Vector3.up, transform.position + Vector3.up);
        if (!plane.Raycast(ray, out float hit))
        {
            return _faceDir;
        }

        Vector3 point = ray.GetPoint(hit);
        Vector3 aim = point - _weaponPoint.position;
        aim.y = 0f;
        return aim.sqrMagnitude > 0.01f ? aim.normalized : _faceDir;
    }

    private void TryFire(Vector3 direction)
    {
        if (_fireCooldown > 0f || direction.sqrMagnitude <= 0.01f || _weapon.Ammo == 0)
        {
            return;
        }

        _fireCooldown = 1f / Mathf.Max(0.1f, _weapon.FireRate);
        if (_weapon.Ammo > 0)
        {
            _weapon.Ammo--;
        }

        float spread = Random.Range(-_weapon.Spread, _weapon.Spread);
        direction = Quaternion.Euler(0f, spread, 0f) * direction.normalized;

        var projectileObject = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        projectileObject.name = $"{_weapon.Name} Projectile";
        projectileObject.transform.position = _weaponPoint.position;
        projectileObject.transform.localScale = Vector3.one * 0.22f;
        projectileObject.GetComponent<Renderer>().material.color = _weapon.Color;
        Destroy(projectileObject.GetComponent<Collider>());

        var projectile = projectileObject.AddComponent<ChaosGunProjectile>();
        projectile.Launch(this, direction, _weapon);

        Vector3 recoil = -new Vector3(direction.x, 0f, direction.z).normalized * _weapon.Recoil;
        _rb.AddForce(recoil, ForceMode.VelocityChange);

        if (_weapon.Ammo == 0)
        {
            Equip(ChaosGunWeapon.Pistol());
        }
    }

    public void Equip(ChaosGunWeapon weapon)
    {
        _weapon = weapon;
    }

    public void TakeHit(Vector3 impulse, float damage, ChaosGunFighter attacker)
    {
        if (IsDead || _invincibleTimer > 0f)
        {
            return;
        }

        _lastHitBy = attacker;
        float damagePercent = Mathf.Clamp01((MaxHp - Hp) / MaxHp);
        float scaling = 1f + damagePercent * 2f;
        Vector3 horizontal = new Vector3(impulse.x, 0f, impulse.z) * scaling;
        Vector3 lifted = horizontal + Vector3.up * horizontal.magnitude * 0.28f;
        _rb.AddForce(lifted, ForceMode.VelocityChange);

        Hp = Mathf.Max(0f, Hp - damage);
        StartCoroutine(FlashDamage());
        if (Hp <= 0f)
        {
            Die();
        }
    }

    private System.Collections.IEnumerator FlashDamage()
    {
        foreach (var r in _renderers)
        {
            r.material.color = Color.white;
        }
        yield return new WaitForSeconds(0.08f);
        foreach (var r in _renderers)
        {
            if (r != null)
            {
                r.material.color = _playerControlled ? new Color(0.1f, 0.45f, 1f) : new Color(1f, 0.22f, 0.12f);
            }
        }
    }

    private void Die()
    {
        if (IsDead)
        {
            return;
        }

        IsDead = true;
        Deaths++;
        Lives--;
        if (_lastHitBy != null && _lastHitBy != this)
        {
            _lastHitBy.Kills++;
        }

        _rb.linearVelocity = Vector3.zero;
        _rb.angularVelocity = Vector3.zero;
        _collider.enabled = false;
        SetRenderersVisible(false);
        _respawnTimer = 1.3f;
    }

    private void Respawn()
    {
        transform.position = _game.RandomSpawn;
        Hp = MaxHp;
        IsDead = false;
        _collider.enabled = true;
        SetRenderersVisible(true);
        _weapon = ChaosGunWeapon.Pistol();
        _invincibleTimer = 2.4f;
        _rb.linearVelocity = Vector3.zero;
    }

    private ChaosGunFighter FindTarget()
    {
        ChaosGunFighter best = null;
        float bestDistance = float.MaxValue;
        foreach (var fighter in ChaosGunGame.Fighters)
        {
            if (fighter == null || fighter == this || fighter.IsDead || fighter.GameOver)
            {
                continue;
            }

            float distance = Vector3.Distance(transform.position, fighter.transform.position);
            if (distance < bestDistance)
            {
                bestDistance = distance;
                best = fighter;
            }
        }
        return best;
    }

    private bool IsGrounded()
    {
        return Physics.SphereCast(transform.position + Vector3.up * 0.35f, 0.42f, Vector3.down, out _, 0.55f, ~0, QueryTriggerInteraction.Ignore);
    }

    private bool HasGroundAhead(Vector3 dir)
    {
        Vector3 origin = transform.position + dir.normalized * 2.5f + Vector3.up * 0.5f;
        return Physics.Raycast(origin, Vector3.down, 2.2f, ~0, QueryTriggerInteraction.Ignore);
    }

    private void SetRenderersVisible(bool visible)
    {
        foreach (var r in _renderers)
        {
            if (r != null)
            {
                r.enabled = visible;
            }
        }
    }
}

public sealed class ChaosGunProjectile : MonoBehaviour
{
    private ChaosGunFighter _shooter;
    private Vector3 _direction;
    private float _speed;
    private float _knockback;
    private float _damage;
    private float _life;

    public void Launch(ChaosGunFighter shooter, Vector3 direction, ChaosGunWeapon weapon)
    {
        _shooter = shooter;
        _direction = direction.normalized;
        _speed = weapon.BulletSpeed;
        _knockback = weapon.Knockback;
        _damage = weapon.Damage;
        _life = weapon.Name == "Sniper" ? 2.5f : 1.6f;
        transform.rotation = Quaternion.LookRotation(_direction);
    }

    private void FixedUpdate()
    {
        _life -= Time.fixedDeltaTime;
        if (_life <= 0f)
        {
            Destroy(gameObject);
            return;
        }

        Vector3 start = transform.position;
        Vector3 move = _direction * (_speed * Time.fixedDeltaTime);
        if (Physics.SphereCast(start, 0.12f, _direction, out var hit, move.magnitude, ~0, QueryTriggerInteraction.Ignore))
        {
            var fighter = hit.collider.GetComponentInParent<ChaosGunFighter>();
            if (fighter != null && fighter != _shooter)
            {
                fighter.TakeHit(_direction * _knockback, _damage, _shooter);
                Destroy(gameObject);
                return;
            }

            if (fighter == null)
            {
                Destroy(gameObject);
                return;
            }
        }

        transform.position += move;
    }
}

public sealed class ChaosGunWeaponPickup : MonoBehaviour
{
    public ChaosGunWeapon weapon;

    private void Update()
    {
        transform.Rotate(0f, 110f * Time.deltaTime, 0f, Space.World);
        transform.position += Vector3.up * Mathf.Sin(Time.time * 4f) * 0.003f;
    }

    private void OnTriggerEnter(Collider other)
    {
        var fighter = other.GetComponentInParent<ChaosGunFighter>();
        if (fighter == null || fighter.IsDead)
        {
            return;
        }

        fighter.Equip(weapon ?? ChaosGunWeapon.RandomPrimary());
        Destroy(gameObject);
    }
}

public sealed class ChaosGunHud : MonoBehaviour
{
    private ChaosGunGame _game;

    public void Bind(ChaosGunGame game)
    {
        _game = game;
    }

    private void OnGUI()
    {
        GUI.color = Color.white;
        GUI.Label(new Rect(18, 14, 680, 24), "ChaosGun Unity Migration - WASD move | Space jump | Mouse aim/fire | 1 pistol | Pickups change weapons");

        float y = 44f;
        foreach (var fighter in ChaosGunGame.Fighters)
        {
            if (fighter == null)
            {
                continue;
            }

            var weapon = fighter.CurrentWeapon;
            string ammo = weapon.Ammo < 0 ? "INF" : weapon.Ammo.ToString();
            GUI.Label(new Rect(18, y, 720, 24),
                $"{fighter.DisplayName}: Lives {fighter.Lives}  HP {fighter.Hp:0}  K/D {fighter.Kills}/{fighter.Deaths}  Weapon {weapon.Name} [{ammo}]");
            y += 24f;
        }

        if (_game != null && !string.IsNullOrEmpty(_game.Winner))
        {
            GUI.color = Color.yellow;
            GUI.Label(new Rect(Screen.width / 2f - 140f, Screen.height / 2f - 20f, 360f, 60f), $"Winner: {_game.Winner}   Press R");
        }
    }
}
