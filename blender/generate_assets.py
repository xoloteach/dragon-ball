"""Rebuild original arena and fighter GLBs with Blender 5.2 headless.

blender -b -t 4 --python blender/generate_assets.py
"""
import bpy
import math
import random
from mathutils import Vector
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "models"
OUT.mkdir(parents=True, exist_ok=True)
random.seed(42)


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def mat(name, color, roughness=0.8, emission=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (*color, 1)
    bs.inputs["Roughness"].default_value = roughness
    if emission:
        bs.inputs["Emission Color"].default_value = (*color, 1)
        bs.inputs["Emission Strength"].default_value = emission
    return m


skin = mat("warm porcelain skin", (0.95, 0.72, 0.58))
skin_shadow = mat("skin warm contour", (0.72, 0.37, 0.25))
gi = mat("umber martial gi", (0.24, 0.105, 0.068))
gi_light = mat("gi top plane", (0.38, 0.18, 0.12))
blue = mat("cobalt blue fabric", (0.025, 0.19, 0.65))
blue_light = mat("blue highlight", (0.075, 0.38, 0.93))
hair = mat("sun gold hair", (1.0, 0.59, 0.015), emission=0.22)
hair_light = mat("hair lit planes", (1.0, 0.88, 0.14), emission=0.26)
hair_shadow = mat("hair amber planes", (0.76, 0.29, 0.014))
ink = mat("ink contours", (0.055, 0.035, 0.045))
eye_white = mat("ivory eye whites", (0.9, 0.96, 0.87))
iris = mat("teal irises", (0.06, 0.63, 0.61))
halo_mat = mat("halo luminous gold", (1.0, 0.78, 0.14), emission=3.0)
rock_a = mat("ochre sandstone", (0.34, 0.205, 0.125))
rock_b = mat("sandstone lit", (0.53, 0.355, 0.205))
rock_c = mat("shadow basalt", (0.17, 0.18, 0.22))
grass = mat("dry grass", (0.28, 0.34, 0.13))


def parent(obj, p):
    if p:
        obj.parent = p
    return obj


def empty(name, loc=(0, 0, 0), p=None):
    ob = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(ob)
    ob.location = loc
    parent(ob, p)
    return ob


def uv(name, loc, scale, material, p=None, seg=16, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, location=(0, 0, 0))
    ob = bpy.context.object
    ob.name = name
    ob.location = loc
    ob.scale = scale
    ob.data.materials.append(material)
    parent(ob, p)
    for f in ob.data.polygons:
        f.use_smooth = True
    return ob


def loft(name, points, radii, material, p=None, sides=12, phase=0):
    verts = []
    faces = []
    for i, pt in enumerate(points):
        for j in range(sides):
            t = 2 * math.pi * j / sides + phase
            verts.append((pt[0] + math.cos(t)*radii[i][0], pt[1] + math.sin(t)*radii[i][1], pt[2]))
    faces.append(tuple(reversed(range(sides))))
    for i in range(len(points)-1):
        for j in range(sides):
            a = i*sides+j
            b = i*sides+(j+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces.append(tuple((len(points)-1)*sides+j for j in range(sides)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(material)
    parent(ob,p)
    return ob


def spike(name, path, widths, depth, materials, p=None):
    """Tapered, faceted hair blade with gold face and amber side planes."""
    verts=[]
    n=len(path)
    for i, (x,y,z) in enumerate(path):
        w=widths[i]
        verts.extend([(x-w,y,z),(x,y-depth*0.48,z+0.06),(x+w,y,z),(x,y+depth*0.52,z-0.04)])
    faces=[]
    ids=[]
    for i in range(n-1):
        for j in range(4):
            faces.append((4*i+j,4*i+(j+1)%4,4*(i+1)+(j+1)%4,4*(i+1)+j))
            ids.append(j%3)
    faces.append((0,3,2,1)); ids.append(1)
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces); mesh.update()
    ob=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(ob)
    for m in materials: mesh.materials.append(m)
    for f,idx in zip(mesh.polygons,ids): f.material_index=idx
    parent(ob,p)
    bevel=ob.modifiers.new("blade edge glints","BEVEL"); bevel.width=0.023; bevel.segments=1
    weighted=ob.modifiers.new("weighted facet normals","WEIGHTED_NORMAL")
    return ob


def torus(name, loc, major, minor, material, p=None, rotation=(0,0,0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                      major_segments=40, minor_segments=8, location=loc)
    ob=bpy.context.object; ob.name=name; ob.rotation_euler=rotation
    ob.data.materials.append(material); parent(ob,p)
    return ob


def animation_library():
    """Object-rig NLA clips exported as independent glTF animations."""
    names=("Torso","Head","LArm","RArm","LForearm","RForearm","LLeg","RLeg")
    clips={
      "fight_idle":(30,{"Torso":(-.035,0,0),"LArm":(-.38,0,-.15),"RArm":(-.42,0,.15),
                       "LForearm":(-.28,0,0),"RForearm":(-.28,0,0)}),
      "sprint":(24,{"Torso":(-.32,0,0),"LArm":(.82,0,-.12),"RArm":(-1.0,0,.12),
                     "LLeg":(-.83,0,0),"RLeg":(.86,0,0)}),
      "flight":(30,{"Torso":(-.47,0,0),"LArm":(-1.6,0,-.27),"RArm":(-1.5,0,.25),
                     "LLeg":(.28,0,-.08),"RLeg":(.32,0,.08)}),
      "jab":(14,{"Torso":(-.12,0,-.22),"LArm":(-1.85,0,-.10),"LForearm":(-.14,0,0),
                   "RArm":(-.45,0,.15)}),
      "cross":(17,{"Torso":(-.17,0,.28),"RArm":(-2.05,0,.12),"RForearm":(-.11,0,0),
                     "LArm":(-.60,0,-.16)}),
      "rising_kick":(21,{"Torso":(.2,0,-.12),"RLeg":(-1.50,0,.06),"RArm":(-.95,0,.2),
                            "LArm":(-.7,0,-.12)}),
      "elbow":(17,{"Torso":(-.2,0,-.42),"LArm":(-1.1,.52,-.28),"LForearm":(-1.2,0,0)}),
      "heavy":(25,{"Torso":(-.32,0,.38),"RArm":(-2.35,0,.18),"RForearm":(-.45,0,0),
                     "LLeg":(.25,0,0)}),
      "launcher":(27,{"Torso":(-.38,0,.30),"RArm":(-2.5,0,.28),"RLeg":(-1.05,0,0),
                        "LArm":(-.75,0,-.16)}),
      "guard":(20,{"LArm":(-1.1,0,-.45),"RArm":(-1.1,0,.45),
                     "LForearm":(-.9,0,0),"RForearm":(-.9,0,0)}),
      "hit":(18,{"Torso":(.38,0,-.28),"Head":(.24,0,.12),"LArm":(.35,0,-.3),"RArm":(.46,0,.35)}),
      "knockback":(33,{"Torso":(.8,0,.22),"Head":(.34,0,0),"LArm":(.7,0,-.7),
                         "RArm":(.66,0,.7),"LLeg":(-.3,0,0),"RLeg":(.34,0,0)}),
      "beam":(37,{"Torso":(-.22,0,0),"LArm":(-1.48,0,-.18),"RArm":(-1.65,0,.18),
                    "LForearm":(-.16,0,0),"RForearm":(-.17,0,0)}),
      "ultimate":(66,{"Torso":(-.42,0,0),"Head":(-.15,0,0),"LArm":(-2.35,0,-.47),
                        "RArm":(-2.35,0,.47),"LLeg":(.26,0,0),"RLeg":(.28,0,0)}),
    }
    for clip,(duration,peak) in clips.items():
        for name in names:
            ob=bpy.data.objects.get(name)
            if ob is None: continue
            ob.animation_data_create()
            action=bpy.data.actions.new(f"{clip}_{name}")
            ob.animation_data.action=action
            wind=tuple(v*.27 for v in peak.get(name,(0,0,0)))
            poses=((1,(0,0,0)),(max(2,int(duration*.25)),wind),
                   (max(3,int(duration*.58)),peak.get(name,(0,0,0))),
                   (duration,(0,0,0)))
            for frame,rotation in poses:
                ob.rotation_euler=rotation
                ob.keyframe_insert(data_path="rotation_euler",frame=frame,group=clip)
            ob.animation_data.action=None
            track=ob.animation_data.nla_tracks.new()
            track.name=clip
            track.strips.new(clip,1,action)
            ob.rotation_euler=(0,0,0)


def fighter():
    clear()
    root=empty("FighterRoot")
    hips=empty("Hips",(0,0,1.18),root)
    torso=empty("Torso",(0,0,0.25),hips)
    loft("pleated trousers",[(0,0,-.12),(0,0,.16),(0,0,.34)],[(.37,.25),(.42,.28),(.33,.24)],gi,hips)
    loft("blue waist sash",[(0,0,.31),(0,0,.39),(0,0,.48)],[(.4,.27),(.43,.29),(.38,.26)],blue,hips)
    for i in range(4):
        loft("sash fold %d"%i,[(0,0,.345+i*.028),(0,0,.363+i*.028)],[(.425,.295),(.425,.295)],blue_light if i%2 else blue,hips,sides=16)
    loft("blue undershirt",[(0,0,0.18),(0,0,.53),(0,0,.96)],[(.37,.26),(.46,.30),(.40,.27)],blue,torso)
    loft("gi sleeveless outer",[(0,0,.23),(0,0,.55),(0,0,.81)],[(.38,.27),(.49,.31),(.46,.30)],gi,torso)
    # Blue V-neck inset, triangular and clearly visible from the front.
    spike("blue V neckline",[(0,-.31,.88),(0,-.35,.65),(0,-.33,.54)],[.34,.22,.01],.055,[blue_light,blue,blue],torso)
    for sign in (-1,1):
        uv("pectoral contour",(sign*.22,-.27,.71),(.25,.055,.13),gi_light,torso)
        uv("gi shoulder fold",(sign*.40,-.015,.78),(.15,.29,.18),gi,torso)
        spike("diagonal gi lapel",[(sign*.33,-.30,.87),(sign*.18,-.345,.68),(sign*.06,-.345,.55)],
              [.07,.08,.005],.08,[gi_light,gi,gi],torso)
        spike("loose gi hem",[(sign*.25,-.27,.38),(sign*.32,-.29,.22),(sign*.40,-.30,.13)],
              [.14,.15,0],.07,[gi,gi_light,gi],torso)
    loft("neck",[(0,0,.85),(0,0,1.02),(0,0,1.18)],[(.17,.16),(.19,.17),(.19,.17)],skin,torso)
    uv("throat shadow",(0,-.157,1.045),(.08,.018,.12),skin_shadow,torso)
    head=empty("Head",(0,0,1.14),torso)
    uv("jaw and face",(0,-.01,.235),(.315,.24,.365),skin,head,seg=24,rings=12)
    uv("pointed chin",(0,-.055,-.038),(.23,.19,.17),skin,head,seg=16,rings=8)
    uv("strong nose bridge",(0,-.255,.245),(.066,.085,.15),skin,head)
    uv("nose plane",(0,-.313,.165),(.083,.057,.045),skin_shadow,head)
    for sign in (-1,1):
        uv("ear",(sign*.31,-.018,.20),(.07,.055,.13),skin,head)
        uv("ear hollow",(sign*.357,-.07,.20),(.025,.016,.075),skin_shadow,head)
        uv("eye white",(sign*.135,-.237,.305),(.112,.020,.031),eye_white,head,seg=12)
        uv("slit teal eye",(sign*.14,-.262,.301),(.039,.012,.027),iris,head,seg=12)
        uv("pupil",(sign*.14,-.274,.300),(.013,.007,.024),ink,head,seg=10)
        brow=uv("severe angled brow",(sign*.135,-.267,.375),(.135,.022,.030),hair_shadow,head,seg=12)
        brow.rotation_euler[1]=sign*.36
        cheek=uv("cheek cel-shadow",(sign*.23,-.188,.095),(.035,.010,.067),skin_shadow,head,seg=12)
        cheek.rotation_euler[1]=sign*.32
    uv("grim mouth",(0,-.235,.022),(.10,.012,.013),ink,head,seg=12)
    uv("lower lip",(0,-.232,-.015),(.09,.012,.012),skin_shadow,head,seg=12)
    # Exaggerated interlocking spikes: broad wings sweep backward, crown rises high.
    uv("hair crown",(0,.025,.55),(.31,.28,.25),hair,head)
    specs=[
      ([(-.21,.02,.56),(-.52,.05,.84),(-.78,.06,1.16)],[.18,.17,0]),
      ([(.18,.03,.56),(.40,.03,1.02),(.55,.07,1.42)],[.23,.17,0]),
      ([(-.13,.03,.62),(-.19,.09,1.04),(-.29,.16,1.64)],[.21,.16,0]),
      ([(.02,.08,.64),(.13,.18,1.21),(.28,.32,1.83)],[.23,.19,0]),
      ([(.20,.12,.59),(.50,.37,1.18),(.77,.62,1.66)],[.22,.24,0]),
      ([(.25,.12,.49),(.65,.54,.91),(1.16,.94,1.02)],[.24,.25,0]),
      ([(.26,.12,.35),(.70,.72,.60),(1.40,1.25,.52)],[.27,.24,0]),
      ([(-.21,.17,.49),(-.43,.63,.84),(-.83,1.14,1.06)],[.25,.22,0]),
      ([(-.19,.15,.35),(-.60,.84,.53),(-1.17,1.50,.48)],[.27,.24,0]),
      ([(.09,.21,.38),(.21,.99,.51),(.44,1.90,.34)],[.3,.27,0]),
      ([(-.06,.22,.31),(-.21,1.05,.33),(-.62,1.86,.10)],[.3,.26,0]),
      ([(.19,.14,.25),(.42,.88,.12),(.80,1.63,-.22)],[.25,.24,0]),
      ([(.13,.18,.47),(.66,.48,.73),(1.55,1.08,.62),(2.40,1.60,.23)],[.31,.40,.34,0]),
      ([(.16,.20,.31),(.81,.68,.43),(1.62,1.22,.18),(2.47,1.69,-.21)],[.32,.40,.33,0]),
      ([(.07,.22,.17),(.60,.75,.13),(1.39,1.41,-.17),(2.08,1.85,-.55)],[.30,.36,.28,0]),
      ([(-.13,.16,.47),(-.53,.55,.71),(-1.28,1.10,.58),(-1.77,1.43,.18)],[.27,.35,.30,0]),
      ([(-.16,.21,.20),(-.71,.78,.17),(-1.31,1.52,-.20),(-1.81,1.90,-.55)],[.28,.34,.25,0]),
      ([(.16,.22,.60),(.58,.57,1.00),(1.29,1.02,1.06),(1.86,1.45,.82)],[.25,.34,.25,0]),
      ([(-.17,-.08,.47),(-.37,-.33,.41),(-.52,-.53,.21)],[.13,.11,0]),
      ([(.11,-.08,.50),(.08,-.34,.48),(-.08,-.49,.25)],[.16,.13,0]),
      ([(-.03,-.13,.56),(-.29,-.39,.50),(-.44,-.57,.18)],[.21,.18,0]),
    ]
    for i,(path,widths) in enumerate(specs):
        spike("sculpted golden spike %02d"%i,path,widths,.24 if i<5 else .38,
              [hair_light,hair,hair_shadow],head)
    # Halo is tilted just above and behind the imposing crown.
    torus("golden halo",(0,.17,2.07),.50,.038,halo_mat,head,rotation=(.27,.20,0))
    for sign,side in ((-1,"L"),(1,"R")):
        arm=empty(side+"Arm",(sign*.49,0,.78),torso)
        uv(side+" deltoid",(sign*.085,0,-.105),(.22,.21,.23),skin,arm)
        loft(side+" upper arm",[(sign*.08,0,-.12),(sign*.16,0,-.39),(sign*.17,0,-.51)],[(.19,.18),(.17,.16),(.125,.12)],skin,arm)
        uv(side+" bicep",(sign*.16,-.07,-.31),(.15,.11,.19),skin,arm)
        uv(side+" blue sleeve",(sign*.04,0,-.06),(.20,.21,.11),blue,arm)
        fore=empty(side+"Forearm",(sign*.17,0,-.51),arm)
        loft(side+" forearm",[(0,0,-.02),(sign*.016,-.01,-.20),(sign*.04,-.025,-.42)],[(.13,.13),(.16,.145),(.09,.09)],skin,fore)
        uv(side+" wrist wrap",(sign*.04,-.025,-.395),(.09,.092,.07),blue,fore)
        fist=empty(side+"Fist",(sign*.04,-.025,-.47),fore)
        uv(side+" knuckle",(0,-.012,-.065),(.14,.11,.13),skin,fist)
        for j in range(4):
            uv(side+" finger %d"%j,(sign*(j-1.5)*.048,-.095,-.085),(.028,.045,.07),skin,fist,seg=10)
        leg=empty(side+"Leg",(sign*.22,0,-.08),hips)
        loft(side+" pants leg",[(0,0,-.03),(sign*.025,.015,-.36),(sign*.025,.02,-.71)],[(.19,.20),(.17,.19),(.115,.13)],gi,leg)
        uv(side+" thigh fold",(sign*.01,-.18,-.19),(.12,.035,.17),gi_light,leg)
        shin=empty(side+"Shin",(sign*.025,.02,-.70),leg)
        loft(side+" shin",[(0,0,0),(0,0,-.30),(0,-.02,-.47)],[(.12,.13),(.10,.11),(.09,.09)],blue,shin)
        uv(side+" boot cuff",(0,0,-.10),(.135,.14,.10),blue_light,shin)
        uv(side+" boot foot",(0,-.13,-.48),(.135,.25,.105),blue,shin)
        uv(side+" boot gold stripe",(0,-.28,-.44),(.11,.045,.025),hair,shin)
    animation_library()
    bpy.ops.export_scene.gltf(filepath=str(OUT/"solar_ascendant.glb"),export_format="GLB",use_selection=False,
                              export_apply=False,export_yup=True,export_animation_mode="NLA_TRACKS")
    # Same rig hierarchy, independently shaped rival: compact dark crest,
    # crimson shoulder mantle and no halo. This is a distinct mesh export.
    halo_obj = bpy.data.objects.get("golden halo")
    if halo_obj: bpy.data.objects.remove(halo_obj, do_unlink=True)
    for ob in list(bpy.data.objects):
        if ob.name.startswith("sculpted golden spike"):
            ob.scale = (.69,.65,.76)
    for sign in (-1,1):
        uv("rival plated shoulder",(sign*.48,.03,.82),(.24,.31,.16),rock_c,torso,seg=12,rings=6)
        spike("rival scarf tail",[(sign*.20,.25,.82),(sign*.33,.47,.44),(sign*.46,.62,.05)],
              [.16,.13,0],.16,[blue,gi,gi_light],torso)
    bpy.ops.export_scene.gltf(filepath=str(OUT/"dusk_rival.glb"),export_format="GLB",use_selection=False,
                              export_apply=False,export_yup=True,export_animation_mode="NLA_TRACKS")


def cliff(name, x, y, height, radius, p, hue=0):
    sides=random.choice([8,9,10])
    jitter=[random.uniform(.78,1.2) for _ in range(sides)]
    rings=[(-.45,1.22),(.65,1.08),(height*.28,1.03),(height*.52,.96),
           (height*.67,1.07),(height*.84,.92),(height,.86)]
    verts=[];faces=[]; material_ids=[]
    for k,(z,rad) in enumerate(rings):
        for j in range(sides):
            ang=math.tau*j/sides
            rr=radius*rad*jitter[j]*(1.0+random.uniform(-.06,.06))
            verts.append((x+math.cos(ang)*rr,y+math.sin(ang)*rr,z))
    for k in range(len(rings)-1):
        for j in range(sides):
            faces.append((k*sides+j,k*sides+(j+1)%sides,(k+1)*sides+(j+1)%sides,(k+1)*sides+j))
            material_ids.append((j+k+hue)%3 if k in (2,3,5) else (hue+j//3)%3)
    faces.append(tuple((len(rings)-1)*sides+j for j in range(sides)));material_ids.append(1)
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces);mesh.update()
    ob=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(ob)
    for m in (rock_a,rock_b,rock_c): mesh.materials.append(m)
    for poly,idx in zip(mesh.polygons,material_ids): poly.material_index=idx
    parent(ob,p)
    return ob


def arena():
    clear()
    root=empty("ArenaRoot")
    # Layered desert floor. Collision is handled by a simple Godot arena plane.
    loft("arena bedrock",[(0,0,-.8),(0,0,-.30),(0,0,0)],[(19,19),(19,19),(18.5,18.5)],rock_a,root,sides=32)
    for i in range(140):
        a=random.random()*math.tau
        r=random.uniform(3,17)
        h=random.uniform(.015,.06)
        uv("mottled dust patch",(math.cos(a)*r,math.sin(a)*r,.005),
           (random.uniform(.22,1.25),random.uniform(.17,.65),h),grass if i%4==0 else rock_c if i%5==0 else rock_b,root,seg=8,rings=4)
    # Irregular cliffs frame the horizon while keeping the center readable.
    for i in range(33):
        a=math.tau*i/33+random.uniform(-.085,.085)
        r=random.uniform(20,39)
        x,y=math.cos(a)*r,math.sin(a)*r
        height=random.uniform(3.8,10.5)
        rad=random.uniform(2.0,4.4)
        cliff("stratified mesa %02d"%i,x,y,height,rad,root,i%3)
        if i%3==0:
            cliff("adjoining mesa %02d"%i,x+rad*.8,y-rad*.7,height*.62,rad*.72,root,(i+1)%3)
    for i in range(95):
        a=random.random()*math.tau;r=random.uniform(5,18)
        x,y=math.cos(a)*r,math.sin(a)*r
        s=random.uniform(.12,.72)
        uv("broken stone %02d"%i,(x,y,s*.28),(s,s*.75,s*.5),rock_b if i%3 else rock_c,root,seg=8,rings=4)
    bpy.ops.export_scene.gltf(filepath=str(OUT/"sunscar_arena.glb"),export_format="GLB",use_selection=False,export_yup=True)


fighter()
arena()
print("Generated", OUT/"solar_ascendant.glb", OUT/"sunscar_arena.glb")
